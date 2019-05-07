# Digital Ocean Alpine Linux Image Generator ![Build Status](https://travis-ci.com/benpye/alpine-droplet.svg?branch=master)

This is a tool to generate an Alpine Linux custom image for Digital Ocean. This ensures that the droplet will correctly configure networking and SSH on first boot using Digital Ocean's metadata service. To use this tool make sure you have `qemu-nbd`, `qemu-img`, `bzip2` and `e2fsprogs` installed. This will not work under the Windows Subsystem for Linux (WSL) as it mounts the image during generation.

Once these prerequisites are installed run:

`# ./build-image.sh 3.9`

This will produce `alpine-v3.9-virt-$TIMESTAMP.qcow2.bz2` which can then be uploaded to Digital Ocean and used to create your droplet. Check out their instructions at https://blog.digitalocean.com/custom-images/ for uploading the image and creating your droplet.

If you want to install custom packages, you can add a package.txt file into the script (see example)

You may also supply a repositories-v3.9.txt file to set the alpine repositories.
