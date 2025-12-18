# Linux-on-ChromeOS
An instruction manual containing Linux sudo codes that allow for Chromebooks to download and run programs required to complete CIS coursework across the Peralta Community College District.
    
Updating Linux:

    sudo apt update
    sudo apt upgrade

Enter Y to accept installation.

Installing VSCode:

Add Microsoft Repositories.

    sudo apt install software-properties-common

Enter Y to accept installation.
    
    sudo add-apt-repository "deb [arch=amd64] https://packages.microsoft.com/repos/vscode stable main"
    sudo apt update
    sudo apt upgrade
    sudo apt install curl
    curl https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor > microsoft.gpg
    sudo mv microsoft.gpg /etc/apt/trusted.gpg.d/microsoft.gpg

Add VS Code repository.

    echo "deb [arch=amd64] https://packages.microsoft.com/repos/code stable main" | sudo tee /etc/apt/sources.list.d/vscode.list
    sudo apt update
    sudo apt upgrade
    sudo apt install code

Enter Y to accept installation.

    code

Installing Java JDK:

    sudo apt update
    sudo apt upgrade
    sudo apt install default-jdk

Enter Y to accept installation.

Install Nano.

    sudo apt update
    sudo apt upgrade
    sudo apt install nano

Set JAVA_HOME environment variable.

    nano .bashrc

Add the following line to the end of the file.

    export JAVA_HOME=/usr/lib/jvm/default-java

Save and exit.

Apply changes to the current section.

Test the JAVA_HOME environment variable.

    source .bashrc
    echo $JAVA_HOME

Installing Java JRE:

    sudo apt update
    sudo apt upgrade
    sudo apt install default-jre

    java -version

Installing GitHub Desktop:

    sudo apt-get install gdebi

Enter Y to accept installation.
    
    sudo wget https://github.com/shiftkey/desktop/releases/download/release-3.1.1-linux1/GitHubDesktop-linux-3.1.1-linux1.deb
    sudo gdebi GitHubDesktop-linux-3.1.1-linux1.deb

Enter Y to accept installation.

Installing Jupyter Lab:

Check Python3 Installation.

    sudo apt install python3
    python3 --version

Install Pip.

    sudo apt install python3-pip

Enter Y to accept installation.

    pip install --upgrade pip
    pip install jupyter lab
    sudo apt update
    sudo apt upgrade

Open a new tab in the Linux terminal.

    jupyter lab

Installing Jupyter Notebook:

    pip3 install notebook

Open a new tab in the Linux terminal.
    
    jupyter notebook

Installing and Creating Pandas DataFrames:

Check Pip version.

    pip -v
    sudo apt install python3-pip
    pip3 install pandas
    python3
    >>> import pandas as pd

Move any .tsv files into your computer's main Linux folder.
    
    >>> df = pd.read_table('example.tsv')
    >>> print(df)

Installing JAR files:

Create a directory to store your files.

    mkdir 'directoryname'
    ls
    cd directoryname

Copy 'example.jar' from its original location.

Paste 'example.jar' into the new directory located within your computer's main Linux folder.

Return to your Linux terminal and enter the new directory.

    cd
    ls
    cd directoryname

Launch the JAR file.

    java -jar example.jar

Enjoy AI on ChromeOS.

Don't forget to check out 'Nostalgia-on-ChromeOS' for a free installation of Doom, Minecraft, and Duke Nukem 3D: Atomic Edition on ChromeOS!
