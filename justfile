app := "build/SmartNotch.app"
installed := "/Applications/SmartNotch.app"

# build, bundle into build/SmartNotch.app, ad-hoc sign
build:
    swift build -c release
    mkdir -p {{app}}/Contents/MacOS
    cp .build/release/SmartNotch {{app}}/Contents/MacOS/
    cp Info.plist {{app}}/Contents/
    mkdir -p {{app}}/Contents/Resources
    cp AppIcon.icns {{app}}/Contents/Resources/
    codesign --force --sign - {{app}}

# regenerate AppIcon.icns from Scripts/make-icon.swift
icon:
    swift Scripts/make-icon.swift build/AppIcon.iconset
    iconutil --convert icns --output AppIcon.icns build/AppIcon.iconset

# run the dev build
run: build quit
    open {{app}}

# install to /Applications and launch
install: build quit
    rm -rf {{installed}}
    cp -R {{app}} {{installed}}
    open {{installed}}

uninstall: quit
    rm -rf {{installed}}

quit:
    -pkill -x SmartNotch

clean:
    rm -rf .build build
