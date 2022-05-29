#!/bin/bash -ex

set -e

cd /yuzu

ccache -s

mkdir build || true && cd build
LDFLAGS="-fuse-ld=lld"
# -femulated-tls required due to an incompatibility between GCC and Clang
# TODO(lat9nq): If this is widespread, we probably need to add this to CMakeLists where appropriate
cmake .. \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_CXX_FLAGS="-femulated-tls" \
    -DCMAKE_TOOLCHAIN_FILE="$(pwd)/../CMakeModules/MinGWClangCross.cmake" \
    -DDISPLAY_VERSION=$1 \
    -DENABLE_COMPATIBILITY_LIST_DOWNLOAD=ON \
    -DENABLE_QT_TRANSLATION=ON \
    -DUSE_CCACHE=ON \
    -DYUZU_USE_BUNDLED_SDL2=OFF \
    -DYUZU_USE_EXTERNAL_SDL2=OFF \
    -GNinja
ninja yuzu yuzu-cmd

ccache -s

echo "Tests skipped"
#ctest -VV -C Release

echo 'Prepare binaries...'
cd ..
mkdir package

if [ -d "/usr/x86_64-w64-mingw32/lib/qt5/plugins/platforms/" ]; then
  QT_PLUGINS_PATH='/usr/x86_64-w64-mingw32/lib/qt5/plugins'
else
  #fallback to qt
  QT_PLUGINS_PATH='/usr/x86_64-w64-mingw32/lib/qt/plugins'
fi

find build/ -name "yuzu*.exe" -exec cp {} 'package' \;

# copy Qt plugins
mkdir package/platforms
cp -v "${QT_PLUGINS_PATH}/platforms/qwindows.dll" package/platforms/
cp -rv "${QT_PLUGINS_PATH}/mediaservice/" package/
cp -rv "${QT_PLUGINS_PATH}/imageformats/" package/
cp -rv "${QT_PLUGINS_PATH}/styles/" package/
rm -f package/mediaservice/*d.dll

for i in package/*.exe; do
  # we need to process pdb here, however, cv2pdb
  # does not work here, so we just simply strip all the debug symbols
  x86_64-w64-mingw32-strip "${i}"
done

pip3 install pefile
python3 .ci/scripts/windows/scan_dll.py package/*.exe package/imageformats/*.dll "package/"

# copy FFmpeg libraries
EXTERNALS_PATH="$(pwd)/build/externals"
FFMPEG_DLL_PATH="$(find "${EXTERNALS_PATH}" -maxdepth 1 -type d | grep 'ffmpeg-')/bin"
find ${FFMPEG_DLL_PATH} -type f -regex ".*\.dll" -exec cp -v {} package/ ';'

# copy libraries from yuzu.exe path
find "$(pwd)/build/bin/" -type f -regex ".*\.dll" -exec cp -v {} package/ ';'
