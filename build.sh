#!/bin/bash

if [ -z "$SM_DIR" ]; then
    SM_DIR="/opt/sourcemod/addons/sourcemod/scripting"
fi

if [ -z "$BUILD_DIR" ]; then
    BUILD_DIR="$(pwd)/build"
fi

if [ -z "$SRC_DIR" ]; then
    SRC_DIR="$(pwd)/scripting"
fi

for f in $SRC_DIR/*.sp; do
    if [ -f "$f" ]; then
        echo "Building $f..."

        $SM_DIR/spcomp64 $f -D $BUILD_DIR -i $SM_DIR/include -i $SRC_DIR/include

        if [ $? -eq 0 ]; then
            bn=$(basename "$f" .sp)

            echo "Built plugin to '$BUILD_DIR/$bn.smx'!"
        fi
    fi
done