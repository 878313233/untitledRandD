# Nostalgia-on-ChromeOS
You can also keep the lights on if that's your thing.


Updating Linux:

    sudo apt update
    sudo apt upgrade

Press Y to accept installation.

Installing Doom:

    sudo apt-get install chocolate-doom
    doom

That's it really. Enjoy Doom on ChromeOS.

Installing Minecraft:

Make a new directory titled 'Minecraft' (or whatever else you want) and enter the directory.

    mkdir Minecraft
    cd Minecraft

Get Minecraft Java & Bedrock Edition for Linux Distributions from the link below:

    https://www.minecraft.net/en-us/download

Copy and paste 'Minecraft.deb' into the 'Minecraft' directory located in your computer's Linux folder.

Install 'Minecraft.deb'.
    
    sudo dpkg -i Minecraft.deb
    sudo apt-get install -f

Run the Minecraft launcher.

    minecraft-launcher

From here you'll encounter a keyring request. You can skip over it by exiting the window.

Login using your Microsoft account and brace for another keyring request. Once fully updated, restart your Linux terminal and run the launcher again.

Enjoy Minecraft on ChromeOS.
    
Installing 'Duke Nukem 3D: Atomic Edition:

Download prerequisites.

    sudo apt-get install build-essential nasm libgl1-mesa-dev libsdl2-dev flac libflac-dev libvpx-dev libgtk2.0-dev freepats

Press Y to accept installation.

Download 'eduke32_src_20240217-10554-8afa42e38.tar.xz' from the link below.

    https://dukeworld.com/eduke32/synthesis/latest/

Download 'DUKE3D.GRP' by selecting 'Duke3d Atomic Edition/DUKE3D.GRP' from the link below.

    https://ia800902.us.archive.org/view_archive.php?archive=/13/items/Duke3dAtomicEdition/Duke3d%20Atomic%20Edition.rar

Make a directory titled 'DukeNukem' (or whatever else you want).

Copy and paste 'eduke32_src_20240217-10554-8afa42e38.tar.xz' from your computer's downloads folder and into the 'DukeNukem' directory located in your computer's Linux folder.

Enter the directory.

    cd DukeNukem

Unzip 'eduke32_src_20240217-10554-8afa42e38.tar.xz'.

    tar -xf eduke32_src_20240217-10554-8afa42e38.tar.xz

Enter the unzipped folder.

    cd eduke32_20240217-10554-8afa42e38

Copy and paste 'DUKE3D.GRP' from your computer's downloads folder into 'eduke32_20240217-10554-8afa42e38' located in your computer's Linux folder.

Compile 'DUKE3D.GRP'.

    make RELEASE=0

Run the game.
    
    ./eduke32

Enjoy 'Duke Nukem 3D: Atomic Edition' on ChromeOS.
