ApolloDeveloperKit
==================

[![Build Status](https://travis-ci.org/manicmaniac/ApolloDeveloperKit.svg?branch=master)](https://travis-ci.org/manicmaniac/ApolloDeveloperKit)
[![Maintainability](https://api.codeclimate.com/v1/badges/c45fc7657ce194edee35/maintainability)](https://codeclimate.com/github/manicmaniac/ApolloDeveloperKit/maintainability)
[![CocoaPods Compatible](https://img.shields.io/cocoapods/v/ApolloDeveloperKit.svg)](https://img.shields.io/cocoapods/v/ApolloDeveloperKit.svg)
[![Carthage Compatible](https://img.shields.io/badge/Carthage-compatible-4BC51D.svg?style=flat)](https://github.com/Carthage/Carthage)
[![Platform](https://img.shields.io/cocoapods/p/ApolloDeveloperKit.svg?style=flat)](https://alamofire.github.io/ApolloDeveloperKit)

[Apollo Client Devtools](https://github.com/apollographql/apollo-client-devtools) bridge for [Apollo iOS](https://github.com/apollographql/apollo-ios).

Screenshots
-----------

<img width="960" alt="apollo-developer-kit-queries-1920" src="https://user-images.githubusercontent.com/1672393/60062041-84949600-9732-11e9-9c70-ee45e5417db6.png">

Prerequisites
-------------

- Xcode 10
- Carthage
- Google Chrome
- [Apollo Client Devtools](https://github.com/apollographql/apollo-client-devtools)

Installation
------------

### Install from Carthage

Add the following lines to your Cartfile.

```
github "apollographql/apollo-ios"
github "manicmaniac/ApolloDeveloperKit"
```

Then run `carthage update --platform iOS`.

### Install from CocoaPods

Add the following lines to your Podfile.

```
pod 'Apollo'
pod 'ApolloDeveloperKit'
```

Then run `pod install`.

Setup
-----

First, in order to hook Apollo's cache and network layer, you need to use `DebuggableNetworkTransport` and `DebuggableInMemoryNormalizedCache` instead of usual ones.

```swift
let networkTransport = DebuggableNetworkTransport(networkTransport: HTTPNetworkTransport(url: url))
let cache = DebuggableInMemoryNormalizedCache()
```

Second, instantiate `ApolloStore` and `ApolloClient` with debuggable ingredients.

```swift
let store = ApolloStore(cache: cache)
let client = ApolloClient(networkTransport: networkTransport: store: store)
```

Finally, create `ApolloDebugServer` and run.

```swift
let debugServer = ApolloDebugServer(cache: cache, networkTransport: networkTransport)
self.debugServer = debugServer // Note: you need to retain debugServer's reference
debugServer.start(port: 8081)
```

Full example:

```swift
import Apollo
import ApolloDeveloperKit
import UIKit

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?
    private var client: ApolloClient!
    private var debugServer: ApolloDebugServer?

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        let url = URL(string: "https://example.com/graphql")!
        #if DEBUG
            let networkTransport = DebuggableNetworkTransport(networkTransport: HTTPNetworkTransport(url: url))
            let cache = DebuggableNormalizedCache(cache: InMemoryNormalizedCache())
            let store = ApolloStore(cache: cache)
            client = ApolloClient(networkTransport: networkTransport, store: store)
            debugServer = ApolloDebugServer(networkTransport: networkTransport, cache: cache)
            do {
                try debugServer.start(port: 8081)
            } catch let error {
                print(error)
            }
        #else
            client = ApolloClient(url: url)
        #endif
        return true
    }
}
```

Excluding ApolloDeveloperKit from Release (App Store) Builds
------------------------------------------------------------

All instructions in this section are written based on [Flipboard/FLEX](https://github.com/Flipboard/FLEX)'s way.

Since ApolloDeveloperKit is originally designed for debug use only, it should not be exposed to end-users.

Fortunately, it is easy to exclude ApolloDeveloperKit framework from Release builds. The strategies differ depending on how you integrated it in your project, and are described below.

Please make sure your code is properly excluding ApolloDeveloperKit with `#if DEBUG` statements before starting these instructions.
Otherwise it will be linked to your app unexpectedly.
See `Example/AppDelegate.swift` to see how to do it.

### For CocoaPods users

CocoaPods automatically excludes ApolloDeveloperKit from release builds if you only specify the Debug configuration for CocoaPods in your Podfile.

### For Carthage users

1. Do NOT add `ApolloDeveloperKit.framework` to the embedded binaries of your target, as it would otherwise be included in all builds (therefore also in release ones).
2. Instead, add `$(PROJECT_DIR)/Carthage/Build/iOS` to your target *Framework Search Paths* (this setting might already be present if you already included other frameworks with Carthage).
This makes it possible to import the ApolloDeveloperKit framework from your source files. It does not harm if this setting is added for all configurations, but it should at least be added for the debug one.
3. Add a *Run Script Phase* to your target (inserting it alter the existing `Link Binary with Libraries` phase, for example), and which will embed `ApolloDeveloperKit.framework` in debug builds only:

```
if [ "$CONFIGURATION" == "Debug" ]; then
  /usr/local/bin/carthage copy-frameworks
fi
```

Finally, add `$(SRCROOT)/Carthage/Build/iOS/ApolloDeveloperKit.framework` as input file of this script phase.

### For users those who copy all the source files to the project manually

Now there's no easy way but you can exclude ApolloDeveloperKit by setting user defined build variable named `EXCLUDED_SOURCE_FILE_NAMES`.
The value for the variable is a space-separated list of each filenames in ApolloDeveloperKit.
Sorry for the inconvenience.

Usage
-----

Open browser after launching Simulator and jump to `http://localhost:8081` (or other specified port) on your Chrome.
Then [open developer tools](https://developers.google.com/web/tools/chrome-devtools/open) and select `Apollo` tab.

Development
-----------

### API Documentation

Auto-generated API documentation is [here](https://manicmaniac.github.io/ApolloDeveloperKit).

### Run Example App

Since Example app is slightly modified version of [apollographql/frontpage-ios-app](https://github.com/apollographql/frontpage-ios-app),
you need to start [apollographql/frontpage-server](https://github.com/apollographql/frontpage-server) before runnning the app.

1. Open Xcode and select ApolloDeveloperKitExample scheme.
2. Run and open `http://localhost:8081` in Google Chrome.

License
-------

This software is distributed under the MIT license.
See LICENSE for more detail.
