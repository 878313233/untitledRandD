async function fetchSiteStats() {
    try {
        const res = await fetch("/api/stats");
        const data = await res.json();
        const text = `👥 Total Users on Site: ${data.total_users}`;
        const el1 = document.getElementById("site-user-count-signup");
        const el2 = document.getElementById("site-user-count-login");
        if (el1) el1.innerText = text;
        if (el2) el2.innerText = text;
    } catch (err) {
        console.error("Error fetching site stats:", err);
    }
}

window.addEventListener("DOMContentLoaded", () => {
    fetchSiteStats();
});

let currentUser = {
    id: 1,
    username: "originalusername",
    display_name: "CustomUserName"
};

let onboardingDataTemp = {};

function showLoginScreen(event) {
    if (event) event.preventDefault();
    document.getElementById("signup-screen").classList.remove("active");
    document.getElementById("login-screen").classList.add("active");
}

function showSignupScreen(event) {
    if (event) event.preventDefault();
    document.getElementById("login-screen").classList.remove("active");
    document.getElementById("signup-screen").classList.add("active");
}

function handleLogout() {
    currentUser = {
        id: 1,
        username: "originalusername",
        display_name: "CustomUserName"
    };
    document.getElementById("homepage-screen").classList.remove("active");
    document.getElementById("login-screen").classList.add("active");
    document.getElementById("login-email").value = "";
    document.getElementById("login-password").value = "";
    document.getElementById("settings-panel").style.display = "none";
}

async function handleLogin(event) {
    event.preventDefault();
    const email = document.getElementById("login-email").value;
    const password = document.getElementById("login-password").value;

    try {
        const res = await fetch("/api/login", {
            method: "POST",
            headers: { "Content-Type": "application/json" },
            body: JSON.stringify({ email, password })
        });

        const data = await res.json();
        if (res.ok) {
            currentUser.id = data.user_id;
            currentUser.username = data.username;
            currentUser.display_name = data.display_name;

            document.getElementById("nav-username").innerText = data.username;
            document.getElementById("nav-display-name").innerText = data.display_name;

            document.getElementById("login-screen").classList.remove("active");
            document.getElementById("homepage-screen").classList.add("active");

            fetchPosts();
        } else {
            alert(data.detail || "Login failed");
        }
    } catch (err) {
        console.error("Login error:", err);
    }
}

let pendingSignupData = {};

async function handleSignup(event) {
    event.preventDefault();
    const firstName = document.getElementById("signup-firstname").value;
    const lastName = document.getElementById("signup-lastname").value;
    const birthday = document.getElementById("signup-birthday").value;
    const email = document.getElementById("signup-email").value;
    const password = document.getElementById("signup-password").value;
    const payrollProvider = document.getElementById("signup-payroll").value;

    pendingSignupData = {
        first_name: firstName,
        last_name: lastName,
        birthday: birthday,
        email: email,
        password: password,
        payroll_provider: payrollProvider || null
    };

    // Reset and show terms modal
    document.getElementById("tc-checkbox").checked = false;
    const btn = document.getElementById("tc-agree-btn");
    btn.disabled = true;
    btn.style.opacity = "0.5";
    btn.style.cursor = "not-allowed";
    document.getElementById("terms-modal").style.display = "flex";
}

function toggleTermsButton() {
    const checked = document.getElementById("tc-checkbox").checked;
    const btn = document.getElementById("tc-agree-btn");
    if (checked) {
        btn.disabled = false;
        btn.style.opacity = "1";
        btn.style.cursor = "pointer";
    } else {
        btn.disabled = true;
        btn.style.opacity = "0.5";
        btn.style.cursor = "not-allowed";
    }
}

function closeTermsModal() {
    document.getElementById("terms-modal").style.display = "none";
}

async function submitSignupAfterTerms() {
    if (!pendingSignupData.email) return;

    try {
        const res = await fetch("/api/signup", {
            method: "POST",
            headers: { "Content-Type": "application/json" },
            body: JSON.stringify(pendingSignupData)
        });

        const data = await res.json();
        if (res.ok) {
            document.getElementById("terms-modal").style.display = "none";
            onboardingDataTemp.user_id = data.user_id;
            onboardingDataTemp.display_name = data.display_name;
            
            // Switch to Onboarding
            document.getElementById("signup-screen").classList.remove("active");
            document.getElementById("onboarding-screen").classList.add("active");
            document.getElementById("ob-name").innerText = pendingSignupData.first_name;
        } else {
            alert(data.detail || "Signup failed");
            document.getElementById("terms-modal").style.display = "none";
        }
    } catch (err) {
        console.error("Signup error:", err);
        document.getElementById("terms-modal").style.display = "none";
    }
}

function selectHistory(importHistory) {
    onboardingDataTemp.import_history = importHistory;
    document.getElementById("onboard-step-1").style.display = "none";
    document.getElementById("onboard-step-2").style.display = "block";
    
    const msg = importHistory 
        ? "Thank you for clarifying. How would you like us to call you?" 
        : "You selected No. Your profile will only show the latest payout you’ve received. How would you like us to call you?";
    document.getElementById("ob-choice-msg").innerText = msg;
    
    document.getElementById("ob-username").value = "user_" + Math.floor(Math.random() * 9000 + 1000);
    document.getElementById("ob-displayname").value = onboardingDataTemp.display_name;
}

async function handleOnboarding(event) {
    event.preventDefault();
    const username = document.getElementById("ob-username").value;
    const displayName = document.getElementById("ob-displayname").value;

    onboardingDataTemp.username = username;
    onboardingDataTemp.display_name = displayName;

    try {
        const res = await fetch("/api/onboarding", {
            method: "POST",
            headers: { "Content-Type": "application/json" },
            body: JSON.stringify(onboardingDataTemp)
        });

        if (res.ok) {
            currentUser.id = onboardingDataTemp.user_id;
            currentUser.username = username;
            currentUser.display_name = displayName;

            document.getElementById("nav-username").innerText = username;
            document.getElementById("nav-display-name").innerText = displayName;

            // Switch to Homepage
            document.getElementById("onboarding-screen").classList.remove("active");
            document.getElementById("homepage-screen").classList.add("active");

            fetchPosts();
        }
    } catch (err) {
        console.error("Onboarding error:", err);
    }
}

async function fetchPosts() {
    try {
        const res = await fetch("/api/posts");
        const posts = await res.json();
        const container = document.getElementById("feed-container");
        container.innerHTML = "";

        // Group by time category
        const categories = ["Today", "Yesterday", "Last Week"];
        categories.forEach(cat => {
            const catPosts = posts.filter(p => p.time_category === cat);
            if (catPosts.length > 0) {
                const header = document.createElement("h3");
                header.className = "time-category-header";
                header.innerText = cat;
                container.appendChild(header);

                catPosts.forEach(post => {
                    const card = document.createElement("div");
                    card.className = "post-card";

                    let commentsHtml = "";
                    post.comments.forEach(c => {
                        commentsHtml += `<div class="comment-item"><strong>${escapeHtml(c.username)}:</strong> ${escapeHtml(c.content)}</div>`;
                    });

                    card.innerHTML = `
                        <div class="post-tag">${escapeHtml(post.post_type.toUpperCase())}</div>
                        <div class="post-title">${escapeHtml(post.title)}</div>
                        <div class="post-meta">@${escapeHtml(post.username)} (${escapeHtml(post.display_name)})</div>
                        <div class="post-body-text">${escapeHtml(post.content)}</div>
                        <div class="post-actions">
                            <button class="action-btn" onclick="likePost(${post.id})">Like (${post.likes_count})</button>
                            <button class="action-btn" onclick="focusComment(${post.id})">Comment</button>
                            <button class="action-btn" onclick="sharePost(${post.id})">Share</button>
                        </div>
                        <div class="comments-section">
                            <div id="comments-${post.id}">${commentsHtml}</div>
                            <div class="comment-input-row">
                                <input type="text" id="comment-input-${post.id}" placeholder="Write a comment...">
                                <button onclick="addComment(${post.id})">Send</button>
                            </div>
                        </div>
                    `;
                    container.appendChild(card);
                });
            }
        });

        if (posts.length === 0) {
            container.innerHTML = "<p class='muted'>No Boring Posts broadcasted yet.</p>";
        }
    } catch (err) {
        console.error("Error fetching posts:", err);
    }
}

async function createPost() {
    const postType = document.getElementById("new-post-type").value;
    const title = document.getElementById("new-post-title").value.trim();
    const content = document.getElementById("new-post-content").value.trim();
    const timeCategory = document.getElementById("new-post-timecat").value;

    if (!title || !content) {
        alert("Please provide both title and content.");
        return;
    }

    try {
        const res = await fetch("/api/posts", {
            method: "POST",
            headers: { "Content-Type": "application/json" },
            body: JSON.stringify({
                post_type: postType,
                title: title,
                content: content,
                time_category: timeCategory,
                user_id: currentUser.id
            })
        });

        if (res.ok) {
            document.getElementById("new-post-title").value = "";
            document.getElementById("new-post-content").value = "";
            fetchPosts();
        }
    } catch (err) {
        console.error("Error creating post:", err);
    }
}

async function likePost(postId) {
    try {
        const res = await fetch(`/api/posts/${postId}/like?user_id=${currentUser.id}`, {
            method: "POST"
        });
        if (res.ok) {
            fetchPosts();
        }
    } catch (err) {
        console.error("Error liking post:", err);
    }
}

async function addComment(postId) {
    const input = document.getElementById(`comment-input-${postId}`);
    const content = input.value.trim();
    if (!content) return;

    try {
        const res = await fetch(`/api/posts/${postId}/comments`, {
            method: "POST",
            headers: { "Content-Type": "application/json" },
            body: JSON.stringify({
                content: content,
                user_id: currentUser.id
            })
        });

        if (res.ok) {
            input.value = "";
            fetchPosts();
        }
    } catch (err) {
        console.error("Error adding comment:", err);
    }
}

function sharePost(postId) {
    alert("Boring Post link copied to clipboard!");
}

function toggleSection(sectionId) {
    const el = document.getElementById(sectionId);
    if (el.style.display === "none") {
        el.style.display = "block";
    } else {
        el.style.display = "none";
    }
}

async function toggleSettings() {
    const panel = document.getElementById("settings-panel");
    if (panel.style.display === "none") {
        panel.style.display = "flex";
        // Fetch current settings
        try {
            const res = await fetch(`/api/user/${currentUser.id}/settings`);
            const data = await res.json();
            document.getElementById("settings-username").innerText = data.username;
            document.getElementById("set-boring-posts").checked = data.show_boring_posts;
            document.getElementById("set-timecards").checked = data.show_timecards;
            document.getElementById("set-payout").checked = data.show_total_payout;
            document.getElementById("set-hide-hris").checked = data.hide_hris_connections;
            document.getElementById("set-asm-alert").checked = data.asm_gm_alert;
        } catch (err) {
            console.error("Error fetching settings:", err);
        }
    } else {
        panel.style.display = "none";
    }
}

async function saveSettings() {
    const payload = {
        show_boring_posts: document.getElementById("set-boring-posts").checked,
        show_timecards: document.getElementById("set-timecards").checked,
        show_total_payout: document.getElementById("set-payout").checked,
        hide_hris_connections: document.getElementById("set-hide-hris").checked,
        asm_gm_alert: document.getElementById("set-asm-alert").checked
    };

    try {
        const res = await fetch(`/api/user/${currentUser.id}/settings`, {
            method: "PUT",
            headers: { "Content-Type": "application/json" },
            body: JSON.stringify(payload)
        });
        if (res.ok) {
            alert("Settings saved successfully!");
            toggleSettings();
        }
    } catch (err) {
        console.error("Error saving settings:", err);
    }
}

function focusComment(postId) {
    document.getElementById(`comment-input-${postId}`).focus();
}

function escapeHtml(text) {
    if (!text) return "";
    const map = {
        '&': '&amp;',
        '<': '&lt;',
        '>': '&gt;',
        '"': '&quot;',
        "'": '&#039;'
    };
    return text.replace(/[&<>"']/g, function(m) { return map[m]; });
}
