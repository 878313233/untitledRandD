import UIKit
import ARKit
import RealityKit
import MapKit

@main
class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?

    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        if !ARGeoTrackingConfiguration.isSupported {
            let storyboard = UIStoryboard(name: "Main", bundle: nil)
            window?.rootViewController = storyboard.instantiateViewController(withIdentifier: "unsupportedDeviceMessage")
        }
        return true
    }

    func application(_ app: UIApplication,
                     open url: URL,
                     options: [UIApplication.OpenURLOptionsKey: Any] = [:]) -> Bool {
        if let viewController = window?.rootViewController as? ViewController {
            viewController.parseGPXFile(with: url)
            return true
        }
        return false
    }
}

struct GeoAnchorWithAssociatedData {
    let geoAnchor: ARGeoAnchor
    let mapOverlay: AnchorIndicator
}

class GPXExporter {
    static let shared = GPXExporter()

    private let gpxPrefix = """
    <?xml version="1.0" encoding="UTF-8" standalone="no" ?>
    <gpx xmlns="http://www.topografix.com/GPX/1/1" creator="Apple Inc.">

    """

    private let waypointTemplate = """
      <wpt lat="LAT_PLACEHOLDER" lon="LON_PLACEHOLDER">
        <ele>ELE_PLACEHOLDER</ele>
        <name>NAME_PLACEHOLDER</name>
      </wpt>

    """

    private let gpxPostfix = "</gpx>"

    func exportGeoAnchors(_ geoAnchors: [ARGeoAnchor], toFileWithURL url: URL) throws {
        var geoAnchorString = gpxPrefix
        for anchor in geoAnchors {
            geoAnchorString.append(gpxWaypoint(from: anchor))
        }
        geoAnchorString.append(gpxPostfix)
        try geoAnchorString.write(to: url, atomically: true, encoding: .utf8)
    }

    private func gpxWaypoint(from geoAnchor: ARGeoAnchor) -> String {
        let waypoint = waypointTemplate
            .replacingOccurrences(of: "LAT_PLACEHOLDER", with: String(format: "%.8f", geoAnchor.coordinate.latitude))
            .replacingOccurrences(of: "LON_PLACEHOLDER", with: String(format: "%.8f", geoAnchor.coordinate.longitude))
            .replacingOccurrences(of: "ELE_PLACEHOLDER", with: geoAnchor.altitude != nil ? String(format: "%.8f", geoAnchor.altitude!) : "")
            .replacingOccurrences(of: "NAME_PLACEHOLDER", with: geoAnchor.name ?? "")
        return waypoint
    }
}

protocol GPXParserDelegate: AnyObject {
    func parser(_ parser: GPXParser, didFinishParsingFileWithAnchors anchors: [ARGeoAnchor])
}

class GPXParser: NSObject, XMLParserDelegate {
    weak var delegate: GPXParserDelegate?

    private var parser: XMLParser?
    private var parsedGeoAnchorData = [String: String]()
    private var currentElementText = ""
    private var anchorsFoundInFile: [ARGeoAnchor] = []

    init?(contentsOf url: URL) {
        guard let parser = XMLParser(contentsOf: url) else { return nil }
        super.init()
        parser.delegate = self
        self.parser = parser
    }

    func parse() {
        parser?.parse()
    }

    func parser(_ parser: XMLParser,
                didStartElement elementName: String,
                namespaceURI: String?,
                qualifiedName qName: String?,
                attributes attributeDict: [String: String] = [:]) {
        if elementName.lowercased() == "wpt" {
            parsedGeoAnchorData = attributeDict
        }
    }

    func parser(_ parser: XMLParser,
                didEndElement elementName: String,
                namespaceURI: String?,
                qualifiedName qName: String?) {
        let tag = elementName.lowercased()
        switch tag {
        case "wpt":
            let name = parsedGeoAnchorData["name"] ?? ""
            if let lat = Double(parsedGeoAnchorData["lat"] ?? ""),
               let lon = Double(parsedGeoAnchorData["lon"] ?? "") {
                let coordinate = CLLocationCoordinate2D(latitude: lat, longitude: lon)
                let altitude = Double(parsedGeoAnchorData["ele"] ?? "")
                let geoAnchor = ARGeoAnchor(name: name, coordinate: coordinate, altitude: altitude)
                anchorsFoundInFile.append(geoAnchor)
            }
        default:
            parsedGeoAnchorData[tag] = currentElementText.trimmingCharacters(in: .whitespacesAndNewlines)
            currentElementText = ""
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        currentElementText += string
    }

    func parserDidEndDocument(_ parser: XMLParser) {
        delegate?.parser(self, didFinishParsingFileWithAnchors: anchorsFoundInFile)
    }
}

class AnchorIndicator: MKCircle {
    convenience init(center: CLLocationCoordinate2D) {
        self.init(center: center, radius: 3.0)
    }
}

extension simd_float4x4 {
    var translation: SIMD3<Float> {
        get {
            return SIMD3<Float>(columns.3.x, columns.3.y, columns.3.z)
        }
        set(newValue) {
            columns.3.x = newValue.x
            columns.3.y = newValue.y
            columns.3.z = newValue.z
        }
    }
}

extension Entity {
    static func placemarkEntity(for arAnchor: ARAnchor) -> AnchorEntity {
        let placemarkAnchor = AnchorEntity(anchor: arAnchor)
        let sphereIndicator = generateSphereIndicator(radius: 0.1)
        let height = sphereIndicator.visualBounds(relativeTo: nil).extents.y
        sphereIndicator.position.y = height / 2

        let distanceFromGround: Float = 3
        sphereIndicator.move(by: [0, distanceFromGround, 0], scale: .one * 10, after: 0.5, duration: 5.0)
        placemarkAnchor.addChild(sphereIndicator)
        return placemarkAnchor
    }

    static func generateSphereIndicator(radius: Float) -> Entity {
        let indicatorEntity = Entity()
        let innerSphere = ModelEntity.blueSphere.clone(recursive: true)
        indicatorEntity.addChild(innerSphere)
        let outerSphere = ModelEntity.transparentSphere.clone(recursive: true)
        indicatorEntity.addChild(outerSphere)
        return indicatorEntity
    }

    func move(by translation: SIMD3<Float>, scale: SIMD3<Float>, after delay: TimeInterval, duration: TimeInterval) {
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            var transform: Transform = .identity
            transform.translation = self.transform.translation + translation
            transform.scale = self.transform.scale * scale
            self.move(to: transform, relativeTo: self.parent, duration: duration, timingFunction: .easeInOut)
        }
    }
}

extension ModelEntity {
    static let blueSphere = ModelEntity(mesh: MeshResource.generateSphere(radius: 0.066), materials: [UnlitMaterial(color: UIColor(red: 0, green: 0.3, blue: 1.4, alpha: 1))])
    static let transparentSphere = ModelEntity(
        mesh: MeshResource.generateSphere(radius: 0.1),
        materials: [SimpleMaterial(color: UIColor(red: 1, green: 1, blue: 1, alpha: 0.25), roughness: 0.3, isMetallic: true)])
}

final class ViewController: UIViewController, ARSessionDelegate, CLLocationManagerDelegate, MKMapViewDelegate, GPXParserDelegate {
    let arView = ARView(frame: .zero)
    let mapView = MKMapView(frame: .zero)
    let toastLabel = UILabel()
    let undoButton = UIButton(type: .system)
    let menuButton = UIButton(type: .system)
    let trackingStateLabel = UILabel()
    let coachingOverlay = ARCoachingOverlayView()
    let locationManager = CLLocationManager()

    var geoAnchors: [GeoAnchorWithAssociatedData] = []

    var currentAnchors: [ARAnchor] {
        return arView.session.currentFrame?.anchors ?? []
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        arView.session.delegate = self
        mapView.delegate = self
        locationManager.delegate = self
        arView.automaticallyConfigureSession = false
        restartSession()
        arView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(handleTapOnARView(_:))))
        mapView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(handleTapOnMapView(_:))))
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        UIApplication.shared.isIdleTimerDisabled = true
        locationManager.requestWhenInUseAuthorization()
        locationManager.startUpdatingLocation()
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        locationManager.stopUpdatingLocation()
    }

    private func setupUI() {
        view.backgroundColor = .black

        arView.translatesAutoresizingMaskIntoConstraints = false
        mapView.translatesAutoresizingMaskIntoConstraints = false
        toastLabel.translatesAutoresizingMaskIntoConstraints = false
        undoButton.translatesAutoresizingMaskIntoConstraints = false
        menuButton.translatesAutoresizingMaskIntoConstraints = false
        trackingStateLabel.translatesAutoresizingMaskIntoConstraints = false

        mapView.isUserInteractionEnabled = true
        mapView.showsCompass = true
        mapView.showsUserLocation = true

        undoButton.setTitle("Undo", for: .normal)
        menuButton.setTitle("Menu", for: .normal)
        toastLabel.textColor = .white
        toastLabel.font = .systemFont(ofSize: 14, weight: .medium)
        toastLabel.backgroundColor = UIColor.black.withAlphaComponent(0.5)
        toastLabel.isHidden = true
        toastLabel.numberOfLines = 0
        trackingStateLabel.textColor = .white
        trackingStateLabel.font = .systemFont(ofSize: 12)
        trackingStateLabel.numberOfLines = 0

        undoButton.addTarget(self, action: #selector(undoButtonTapped), for: .touchUpInside)
        menuButton.addTarget(self, action: #selector(menuButtonTapped), for: .touchUpInside)

        view.addSubview(arView)
        view.addSubview(mapView)
        view.addSubview(toastLabel)
        view.addSubview(undoButton)
        view.addSubview(menuButton)
        view.addSubview(trackingStateLabel)

        NSLayoutConstraint.activate([
            arView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            arView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            arView.topAnchor.constraint(equalTo: view.topAnchor),
            arView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            mapView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            mapView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            mapView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -16),
            mapView.heightAnchor.constraint(equalToConstant: 180),

            toastLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            toastLabel.centerYAnchor.constraint(equalTo: view.centerYAnchor),

            undoButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            undoButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -18),
            menuButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            menuButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -18),

            trackingStateLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            trackingStateLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            trackingStateLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 8)
        ])
    }

    @objc func menuButtonTapped() {
        let actionSheet = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        actionSheet.addAction(UIAlertAction(title: "Reset Session", style: .destructive, handler: { _ in
            self.restartSession()
        }))
        actionSheet.addAction(UIAlertAction(title: "Load Anchors …", style: .default, handler: { _ in
            self.showGPXFiles()
        }))
        actionSheet.addAction(UIAlertAction(title: "Save Anchors …", style: .default, handler: { _ in
            self.saveAnchors()
        }))
        actionSheet.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        present(actionSheet, animated: true)
    }

    @objc func undoButtonTapped() {
        guard let lastGeoAnchor = geoAnchors.last else {
            showToast("Nothing to undo")
            return
        }

        arView.session.remove(anchor: lastGeoAnchor.geoAnchor)
        mapView.removeOverlay(lastGeoAnchor.mapOverlay)
        geoAnchors.removeLast()
        showToast("Removed last added anchor")
    }

    @objc func handleTapOnARView(_ sender: UITapGestureRecognizer) {
        let point = sender.location(in: view)
        if let result = arView.raycast(from: point, allowing: .estimatedPlane, alignment: .any).first {
            addGeoAnchor(at: result.worldTransform.translation)
        } else {
            showToast("No raycast result.\nTry pointing at a different area\nor move closer to a surface.")
        }
    }

    @objc func handleTapOnMapView(_ sender: UITapGestureRecognizer) {
        let point = sender.location(in: mapView)
        let coordinate = mapView.convert(point, toCoordinateFrom: mapView)
        addGeoAnchor(at: coordinate)
    }

    func restartSession() {
        ARGeoTrackingConfiguration.checkAvailability { available, error in
            if !available {
                let errorDescription = error?.localizedDescription ?? ""
                let recommendation = "Please try again in an area where geotracking is supported."
                let restartAction = UIAlertAction(title: "Restart Session", style: .default) { _ in
                    self.restartSession()
                }
                self.alertUser(withTitle: "Geotracking unavailable",
                              message: "\(errorDescription)\n\(recommendation)",
                              actions: [restartAction])
            }
        }

        let geoTrackingConfig = ARGeoTrackingConfiguration()
        geoTrackingConfig.planeDetection = [.horizontal]
        arView.session.run(geoTrackingConfig, options: .removeExistingAnchors)
        geoAnchors.removeAll()
        arView.scene.anchors.removeAll()
        trackingStateLabel.text = ""

        let anchorOverlays = mapView.overlays.filter { $0 is AnchorIndicator }
        mapView.removeOverlays(anchorOverlays)
        showToast("Running new AR session")
    }

    func addGeoAnchor(at worldPosition: SIMD3<Float>) {
        arView.session.getGeoLocation(forPoint: worldPosition) { location, altitude, error in
            if let error = error {
                self.alertUser(withTitle: "Cannot add geo anchor",
                              message: "An error occurred while translating ARKit coordinates to geo coordinates: \(error.localizedDescription)")
                return
            }
            self.addGeoAnchor(at: location, altitude: altitude)
        }
    }

    func addGeoAnchor(at location: CLLocationCoordinate2D, altitude: CLLocationDistance? = nil) {
        let geoAnchor: ARGeoAnchor
        if let altitude = altitude {
            geoAnchor = ARGeoAnchor(coordinate: location, altitude: altitude)
        } else {
            geoAnchor = ARGeoAnchor(coordinate: location)
        }
        addGeoAnchor(geoAnchor)
    }

    func addGeoAnchor(_ geoAnchor: ARGeoAnchor) {
        guard isGeoTrackingLocalized else {
            alertUser(withTitle: "Cannot add geo anchor",
                      message: "Unable to add geo anchor because geotracking has not yet localized.")
            return
        }
        arView.session.add(anchor: geoAnchor)
    }

    var isGeoTrackingLocalized: Bool {
        if let status = arView.session.currentFrame?.geoTrackingStatus, status.state == .localized {
            return true
        }
        return false
    }

    func distanceFromDevice(_ coordinate: CLLocationCoordinate2D) -> Double {
        if let devicePosition = locationManager.location?.coordinate {
            return MKMapPoint(coordinate).distance(to: MKMapPoint(devicePosition))
        }
        return 0
    }

    func session(_ session: ARSession, didAdd anchors: [ARAnchor]) {
        for geoAnchor in anchors.compactMap({ $0 as? ARGeoAnchor }) {
            DispatchQueue.main.asyncAfter(deadline: .now() + (distanceFromDevice(geoAnchor.coordinate) / 10)) {
                self.arView.scene.addAnchor(Entity.placemarkEntity(for: geoAnchor))
            }

            let anchorIndicator = AnchorIndicator(center: geoAnchor.coordinate)
            self.mapView.addOverlay(anchorIndicator)
            self.geoAnchors.append(GeoAnchorWithAssociatedData(geoAnchor: geoAnchor, mapOverlay: anchorIndicator))
        }
    }

    func session(_ session: ARSession, didFailWithError error: Error) {
        guard error is ARError else { return }
        let errorWithInfo = error as NSError
        let messages = [
            errorWithInfo.localizedDescription,
            errorWithInfo.localizedFailureReason,
            errorWithInfo.localizedRecoverySuggestion
        ]
        let errorMessage = messages.compactMap { $0 }.joined(separator: "\n")
        DispatchQueue.main.async {
            let alertController = UIAlertController(title: "The AR session failed.", message: errorMessage, preferredStyle: .alert)
            let restartAction = UIAlertAction(title: "Restart Session", style: .default) { _ in
                alertController.dismiss(animated: true)
                self.restartSession()
            }
            alertController.addAction(restartAction)
            self.present(alertController, animated: true)
        }
    }

    func session(_ session: ARSession, didChange geoTrackingStatus: ARGeoTrackingStatus) {
        var text = ""
        if geoTrackingStatus.state == .localized {
            text += "Accuracy: \(geoTrackingStatus.accuracy.description)"
        } else {
            switch geoTrackingStatus.stateReason {
            case .none:
                break
            case .worldTrackingUnstable:
                let arTrackingState = session.currentFrame?.camera.trackingState
                if case let .limited(arTrackingStateReason) = arTrackingState {
                    text += "\n\(geoTrackingStatus.stateReason.description): \(arTrackingStateReason.description)."
                } else {
                    text += "\n\(geoTrackingStatus.stateReason.description)."
                }
            default:
                text += "\n\(geoTrackingStatus.stateReason.description)."
            }
        }
        trackingStateLabel.text = text
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        let camera = MKMapCamera(lookingAtCenter: location.coordinate,
                                 fromDistance: CLLocationDistance(250),
                                 pitch: 0,
                                 heading: mapView.camera.heading)
        mapView.setCamera(camera, animated: false)
    }

    func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
        if let anchorOverlay = overlay as? AnchorIndicator {
            let renderer = MKCircleRenderer(circle: anchorOverlay)
            renderer.strokeColor = .white
            renderer.fillColor = .blue
            renderer.lineWidth = 2
            return renderer
        }
        return MKOverlayRenderer()
    }

    func showGPXFiles() {
        guard let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            alertUser(withTitle: "Couldn't list files", message: "Unable to access the documents folder.")
            return
        }

        var gpxURLs: [URL] = []
        if let urlsInDocumentsDirectory = try? FileManager.default
            .contentsOfDirectory(at: documentsDirectory, includingPropertiesForKeys: nil, options: [])
            .filter({ $0.pathExtension.lowercased() == "gpx" })
            .sorted(by: { $0.lastPathComponent < $1.lastPathComponent }) {
            gpxURLs.append(contentsOf: urlsInDocumentsDirectory)
        }

        guard !gpxURLs.isEmpty else {
            alertUser(withTitle: "No GPX files found", message: "Unable to find any saved geo anchors.")
            return
        }

        var alertActions = gpxURLs.map { url in
            UIAlertAction(title: url.lastPathComponent, style: .default) { _ in
                self.parseGPXFile(with: url)
            }
        }

        alertActions.append(UIAlertAction(title: "Cancel", style: .cancel))
        alertUser(withTitle: "Choose GPX file", message: "", actions: alertActions)
    }

    func saveAnchors() {
        let geoAnchors = currentAnchors.compactMap { $0 as? ARGeoAnchor }
        guard !geoAnchors.isEmpty else {
            alertUser(withTitle: "No geo anchors", message: "There are no geo anchors to save.")
            return
        }
        saveAnchorsAsGPXFile(geoAnchors)
    }

    func saveAnchorsAsGPXFile(_ anchors: [ARGeoAnchor]) {
        let alert = UIAlertController(title: "GPX File Name", message: "File name to save the anchors to.", preferredStyle: .alert)
        alert.addTextField { textField in
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "YYYYMMdd-hhmmss"
            textField.text = "GeoAnchors-\(dateFormatter.string(from: Date()))"
            textField.clearsOnInsertion = true
        }

        let saveAction = UIAlertAction(title: "Save to documents", style: .default) { _ in
            guard let documentsDirectory = try? FileManager.default.url(for: .documentDirectory,
                                                                        in: .userDomainMask,
                                                                        appropriateFor: nil,
                                                                        create: true) else {
                self.alertUser(withTitle: "Write Failed", message: "Unable to access the documents folder")
                return
            }

            let fileName = alert.textFields?.first?.text ?? "Untitled"
            let url = documentsDirectory.appendingPathComponent(fileName).appendingPathExtension("gpx")

            do {
                try GPXExporter.shared.exportGeoAnchors(anchors, toFileWithURL: url)
                self.showToast("Saved geo anchor(s)")
            } catch {
                self.showToast("Unable to save geo anchor(s)")
            }
        }

        let shareAction = UIAlertAction(title: "Share", style: .default) { _ in
            let fileName = alert.textFields?.first?.text ?? "Untitled"
            let tempURL = URL(fileURLWithPath: NSTemporaryDirectory())
                .appendingPathComponent(fileName)
                .appendingPathExtension("gpx")
            do {
                try GPXExporter.shared.exportGeoAnchors(anchors, toFileWithURL: tempURL)
                let activityViewController = UIActivityViewController(activityItems: [tempURL], applicationActivities: nil)
                activityViewController.popoverPresentationController?.sourceView = nil
                self.present(activityViewController, animated: true)
            } catch {
                self.showToast("Unable to export geo anchor(s)")
            }
        }

        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel)
        alert.addAction(saveAction)
        alert.addAction(shareAction)
        alert.addAction(cancelAction)
        self.present(alert, animated: true)
    }

    func parseGPXFile(with url: URL) {
        guard let parser = GPXParser(contentsOf: url) else {
            showToast("Unable to open GPX file.")
            return
        }
        parser.delegate = self
        parser.parse()
    }

    func parser(_ parser: GPXParser, didFinishParsingFileWithAnchors anchors: [ARGeoAnchor]) {
        guard isGeoTrackingLocalized else {
            alertUser(withTitle: "Cannot add geo anchor(s)", message: "Unable to add geo anchor(s) because geotracking has not yet localized.")
            return
        }

        if anchors.isEmpty {
            alertUser(withTitle: "No anchors added", message: "GPX file does not contain anchors or is invalid.")
            return
        }

        for anchor in anchors {
            addGeoAnchor(anchor)
        }
        showToast("\(anchors.count) anchor(s) added.")
    }

    func alertUser(withTitle title: String, message: String, actions: [UIAlertAction]? = nil) {
        DispatchQueue.main.async {
            let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
            if let actions = actions { actions.forEach { alert.addAction($0) } }
            else { alert.addAction(UIAlertAction(title: "OK", style: .default)) }
            self.present(alert, animated: true)
        }
    }

    func showToast(_ message: String, duration: TimeInterval = 2) {
        DispatchQueue.main.async {
            self.toastLabel.numberOfLines = message.components(separatedBy: "\n").count
            self.toastLabel.text = message
            self.toastLabel.isHidden = false

            let tag = self.toastLabel.tag + 1
            self.toastLabel.tag = tag

            if duration > 0 {
                DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
                    if self.toastLabel.tag == tag {
                        self.toastLabel.isHidden = true
                    }
                }
            }
        }
    }
}

extension ARGeoTrackingStatus.StateReason {
    var description: String {
        switch self {
        case .none: return "None"
        case .notAvailableAtLocation: return "Geotracking is unavailable here. Please return to your previous location to continue"
        case .needLocationPermissions: return "App needs location permissions"
        case .worldTrackingUnstable: return "Limited tracking"
        case .geoDataNotLoaded: return "Downloading localization imagery. Please wait"
        case .devicePointedTooLow: return "Point the camera at a nearby building"
        case .visualLocalizationFailed: return "Point the camera at a building unobstructed by trees or other objects"
        case .waitingForLocation: return "ARKit is waiting for the system to provide a precise coordinate for the user"
        case .waitingForAvailabilityCheck: return "ARKit is checking Location Anchor availability at your location"
        @unknown default: return "Unknown reason"
        }
    }
}

extension ARGeoTrackingStatus.Accuracy {
    var description: String {
        switch self {
        case .undetermined: return "Undetermined"
        case .low: return "Low"
        case .medium: return "Medium"
        case .high: return "High"
        @unknown default: return "Unknown"
        }
    }
}

extension ARCamera.TrackingState.Reason {
    var description: String {
        switch self {
        case .initializing: return "Initializing"
        case .excessiveMotion: return "Too much motion"
        case .insufficientFeatures: return "Insufficient features"
        case .relocalizing: return "Relocalizing"
        @unknown default: return "Unknown"
        }
    }
}

extension ViewController: ARCoachingOverlayViewDelegate {
    func coachingOverlayViewWillActivate(_ coachingOverlayView: ARCoachingOverlayView) {
        mapView.isUserInteractionEnabled = false
        undoButton.isEnabled = false
        hideUIForCoaching(true)
    }

    func coachingOverlayViewDidDeactivate(_ coachingOverlayView: ARCoachingOverlayView) {
        mapView.isUserInteractionEnabled = true
        undoButton.isEnabled = true
        hideUIForCoaching(false)
    }

    func coachingOverlayViewDidRequestSessionReset(_ coachingOverlayView: ARCoachingOverlayView) {
        restartSession()
    }

    func setupCoachingOverlay() {
        coachingOverlay.delegate = self
        arView.addSubview(coachingOverlay)
        coachingOverlay.goal = .geoTracking
        coachingOverlay.session = arView.session
        coachingOverlay.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            coachingOverlay.centerXAnchor.constraint(equalTo: arView.centerXAnchor),
            coachingOverlay.centerYAnchor.constraint(equalTo: arView.centerYAnchor),
            coachingOverlay.widthAnchor.constraint(equalTo: arView.widthAnchor),
            coachingOverlay.heightAnchor.constraint(equalTo: arView.heightAnchor)
        ])
    }

    func hideUIForCoaching(_ active: Bool) {
        undoButton.isHidden = active
        trackingStateLabel.isHidden = active
    }
}

// MARK: - Example of how to initialize the app view controller if used in a UIKit storyboard
// You can paste this into a view controller file or adapt it to a SwiftUI host.

// final class ExampleStoryboardHostVC: UIViewController {
//     override func viewDidLoad() {
//         super.viewDidLoad()
//         let vc = ViewController()
//         addChild(vc)
//         view.addSubview(vc.view)
//         vc.view.frame = view.bounds
//         vc.didMove(toParent: self)
//     }
// }
