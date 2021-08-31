#!/bin/bash

# change /bin/sh symbolic link
cp -P /bin/sh /bin/sh_back
ln -sf /bin/bash /bin/sh

# run web server compile
./web-build.sh

# restore  /bin/sh symbolic link
mv /bin/sh_back /bin/sh
