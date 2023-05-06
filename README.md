# 📦 Run GNOME Shell in a Container!

Upstream: https://github.com/Schneegans/gnome-shell-pod

_:information_source: I want to thank [@amezin](https://github.com/amezin) for his awesome contributions, which made it possible to transition the images from Ubuntu to Fedora._

## The Idea

Developing high-quality GNOME Shell extensions is challenging due to various reasons.
One major issues is the lack of continuous integration possibilities.
So I thought: Why not try getting GNOME Shell running on the runners of GitHub Actions?
Of course, I know that this is exactly what Podman is not designed to be used for...

**Anyway, here is what already works:**
- [x] Multiple containers for various GNOME Shell versions:
  - [x] [**gnome-shell-pod-32**](https://github.com/Schneegans/gnome-shell-pod/pkgs/container/gnome-shell-pod-32): GNOME Shell 3.36.9 (based on Fedora 32)
  - [x] [**gnome-shell-pod-33**](https://github.com/Schneegans/gnome-shell-pod/pkgs/container/gnome-shell-pod-33): GNOME Shell 3.38.5 (based on Fedora 33)
  - [x] [**gnome-shell-pod-34**](https://github.com/Schneegans/gnome-shell-pod/pkgs/container/gnome-shell-pod-34): GNOME Shell 40.9 (based on Fedora 34)
  - [x] [**gnome-shell-pod-35**](https://github.com/Schneegans/gnome-shell-pod/pkgs/container/gnome-shell-pod-35): GNOME Shell 41.9 (based on Fedora 35)
  - [x] [**gnome-shell-pod-36**](https://github.com/Schneegans/gnome-shell-pod/pkgs/container/gnome-shell-pod-36): GNOME Shell 42.5 (based on Fedora 36)
  - [x] [**gnome-shell-pod-37**](https://github.com/Schneegans/gnome-shell-pod/pkgs/container/gnome-shell-pod-37): GNOME Shell 43.2 (based on Fedora 37)
  - [x] [**gnome-shell-pod-38**](https://github.com/Schneegans/gnome-shell-pod/pkgs/container/gnome-shell-pod-38): GNOME Shell 44.0 (based on Fedora 38)
  - [x] [**gnome-shell-pod-rawhide**](https://github.com/Schneegans/gnome-shell-pod/pkgs/container/gnome-shell-pod-rawhide): This is based on Fedora Rawhide and rebuilt weekly.
- [x] Choose display manager:
  - [x] Wayland
  - [x] X11
- [x] You can launch other applications, such as `gnome-control-center`.
- [x] You can make "screenshots" of GNOME Shell and transfer them to host memory.
- [x] You can install a GNOME Shell extension from host memory and enable it.
- [x] You can use `xdotool` to interact with the extension.
- [x] All of this works locally and on the GitHub hosted runners!

### Changes from upstream

- [x] `ImageMagick` and `yarn` packages added.
- [x] https://github.com/fthx/no-overview/ extension added (as git submodule).
- [ ] build-only and test-only variants with lesser packages to install.

## How Does It Work?

A user called "gnomeshell" will auto-login via `systemd-logind.service.d` and run `gnome-shell` on `xvfb`.
The framebuffer of `xvfb` is mapped to a file which can be copied to host memory and converted to an image.
This way we can actually make "screenshots" of GNOME Shell!

## How Do I Use It?

I wrote a series of blog posts in order to explain how I use these containers for continuous integration test of my GNOME Shell extensions.
For some in-depth examples, you may want to read those:

1. [Bundling the Extension](http://schneegans.github.io/tutorials/2022/02/28/gnome-shell-extensions-ci-01)
2. [Automated Release Publishing](http://schneegans.github.io/tutorials/2022/03/01/gnome-shell-extensions-ci-02)
3. [Automated Tests with GitHub Actions](http://schneegans.github.io/tutorials/2022/03/02/gnome-shell-extensions-ci-03)


Below, you'll find some simple examples to get you started.
You will need to install [imagemagick](https://imagemagick.org/index.php) (for converting the xvfb framebuffer image) and, obviously, [Podman](https://podman.io/).
On Ubuntu-like distributions you can install them with this command:

```bash
sudo apt-get install imagemagick podman
```

### Basic Usage

If you want to play around with GNOME Shell inside the pod, use these commands:

```bash
# Run the container in interactive mode. This will automatically login the
# gnomeshell user.
podman run --rm --cap-add=SYS_NICE --cap-add=IPC_LOCK -ti ghcr.io/schneegans/gnome-shell-pod-33

# Start GNOME Shell.
systemctl --user start "gnome-xsession@:99"

# For example, you can run this command inside the container:
DISPLAY=:99 gnome-control-center
```

Now use another terminal on your host to capture and display a screenshot.

```bash
# Copy the framebuffer of xvfb.
podman cp $(podman ps -q -n 1):/opt/Xvfb_screen0 .

# Convert it to jpeg.
convert xwd:Xvfb_screen0 capture.jpg

# And finally display the image.
# This way we can see that GNOME Shell is actually up and running!
eog capture.jpg
```

<p align="center">
  <img src="pictures/capture2.jpg" />
</p>

You can kill the `gnome-control-center` with <kbd>Ctrl</kbd>+<kbd>C</kbd> in the container and then poweroff the container with `poweroff`.


### Detached Mode

In this example we will download some pictures inside the container and make GNOME Shell use one of them as background image.
The `gnomeshell` user can run passwordless `sudo`, so you can simply install packages.
`podman exec --user gnomeshell` can be used to run arbitrary commands inside the running container. However, many commands interacting with GNOME Shell will require a connection to the D-Bus. To make this easier, the images contain a `/local/bin/set-env.sh` script, which sets all required environment variables.

```bash
# Run the container in detached mode.
POD=$(podman run --rm --cap-add=SYS_NICE --cap-add=IPC_LOCK -td ghcr.io/schneegans/gnome-shell-pod-33)

do_in_pod() {
  podman exec --user gnomeshell --workdir /home/gnomeshell "${POD}" set-env.sh "$@"
}

# Install the gnome-backgrounds package.
do_in_pod sudo dnf -y install gnome-backgrounds

# Set GNOME Shell's background image. This requires a D-Bus connection,
# so we wrap the command in the set-env.sh script.
do_in_pod gsettings set org.gnome.desktop.background picture-uri \
          "file:///usr/share/backgrounds/gnome/adwaita-day.jpg"

# Wait until the user bus is available.
do_in_pod wait-user-bus.sh 

# Start GNOME Shell.
do_in_pod systemctl --user start "gnome-xsession@:99"

# Wait some time until GNOME Shell has been started.
sleep 3

# Now make a screenshot and show it!
podman cp ${POD}:/opt/Xvfb_screen0 . && \
       convert xwd:Xvfb_screen0 capture.jpg && \
       eog capture.jpg

# Now we can stop the container again.
podman stop ${POD}
```

<p align="center">
  <img src="pictures/capture5.jpg" />
</p>

<!--

### Testing an Extension

In this example, we will start the container, install and enable an extension from extensions.gnome.org and finally create a screenshot.
Enabling the extension involves restarting GNOME Shell.
To simplify this process, another script (`/home/gnomeshell/enable-extension.sh`) is contained in the images.

```bash
# Run the container in detached mode.
podman run --rm -td ghcr.io/schneegans/gnome-shell:3.38

# Wait some time to make sure that GNOME Shell has been started.
sleep 5

# Download an extension.
wget https://extensions.gnome.org/extension-data/dash-to-paneljderose9.github.com.v40.shell-extension.zip

# Rename it to UUID.zip. This is expected by the enable-extension.sh script.
mv dash-to-paneljderose9.github.com.v40.shell-extension.zip \
   dash-to-panel@jderose9.github.com.zip

# Copy the archive to the container.
podman cp dash-to-panel@jderose9.github.com.zip $(podman ps -q -n 1):/home/gnomeshell/

# Execute the install script. This installs the extension, restarts GNOME Shell and
# finally enables the extension.
podman exec --user gnomeshell --workdir /home/gnomeshell $(podman ps -q -n 1) ./set-env.sh \
       ./enable-extension.sh dash-to-panel@jderose9.github.com

# Wait some time to make sure that GNOME Shell has been restarted.
sleep 2

# Then make a "screenshot" and display the image.
podman cp $(podman ps -q -n 1):/opt/Xvfb_screen0 . && \
      convert xwd:Xvfb_screen0 capture.jpg && \
      eog capture.jpg

# Finally stop the container.
podman stop $(podman ps -q -n 1)
```

<p align="center">
  <img src="pictures/capture4.jpg" />
</p>


### Interacting with GNOME Shell

If you started the container in detached mode, you can execute commands inside the container using `podman exec`. In this example we will use `xdotool` to simulate mouse input.

```bash
# Run the container in detached mode.
POD=$(podman run --rm --cap-add=SYS_NICE --cap-add=IPC_LOCK -td ghcr.io/schneegans/gnome-shell-pod-33)

do_in_pod() {
  podman exec --user gnomeshell --workdir /home/gnomeshell "${POD}" set-env.sh "$@"
}

# Wait until the user bus is available.
do_in_pod wait-user-bus.sh 

# Start GNOME Shell.
do_in_pod systemctl --user start "gnome-xsession@:99"

# Wait some time until GNOME Shell has been started.
sleep 5

# Click the activities button.
do_in_pod xdotool mousemove 20 10 click 1 && sleep 1

# Click the applications grid button.
do_in_pod xdotool mousemove 50 550 click 1 && sleep 1

# Then make a "screenshot" and display the image.
podman cp ${POD}:/opt/Xvfb_screen0 . && \
       convert xwd:Xvfb_screen0 capture.jpg && \
       eog capture.jpg

# Finally stop the container.
podman stop ${POD}
```

<p align="center">
  <img src="pictures/capture3.jpg" />
</p>


### Using This in a GitHub Action

When you try to use this container in a GitHub actions workflow, you will need to run podman with `sudo` (for whatever reason).
But it works! Once the workflow run is finished, you can download the screenshot as artifact.

```yaml
name: Tests

on:
  push:
    branches:
      - '**'
  pull_request:
    branches:
      - '**'

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
    - name: Run GNOME Shell
      run: |
        sudo apt-get install imagemagick -qq
        POD=$(sudo podman run --rm -td ghcr.io/schneegans/gnome-shell:3.38)
        sleep 5
        sudo podman cp $POD:/opt/Xvfb_screen0 . && convert xwd:Xvfb_screen0 capture.jpg
        sudo podman stop $POD
    - name: Upload Screenshot
      uses: actions/upload-artifact@v2
      with:
        name: screenshot
        path: capture.jpg
```

A real-world example can be seen in the [repository of Fly-Pie](https://github.com/Schneegans/Fly-Pie). Here, a [run-test.sh](https://github.com/Schneegans/Fly-Pie/blob/develop/scripts/run-tests.sh) script executes all the tests on a container. This script can be run locally as well as on the runners of GitHub.

-->

## :octocat: Contributing

Commits should start with a Capital letter and should be written in present tense (e.g. __:tada: Add cool new feature__ instead of __:tada: Added cool new feature__).
You should also start your commit message with **one** applicable emoji.
This does not only look great but also makes you rethink what to add to a commit. Make many but small commits!

Emoji | Description
------|------------
:tada: `:tada:` | When you added a cool new feature.
:wrench: `:wrench:` | When you added a piece of code.
:art: `:art:` | When you improved / added assets like themes.
:rocket: `:rocket:` | When you improved performance.
:memo: `:memo:` | When you wrote documentation.
:beetle: `:beetle:` | When you fixed a bug.
:twisted_rightwards_arrows: `:twisted_rightwards_arrows:` | When you merged a branch.
:fire: `:fire:` | When you removed something.
:truck: `:truck:` | When you moved / renamed something.
