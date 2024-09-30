swift package --disable-sandbox archive --products HttpApiLambda --output-path dist 

# change line 115 in archive plugin 
#                 // FIXME: temporary change to be able to build from the mac command line
#                arguments: ["run", "--rm", "-v", "\(packageDirectory.string)/../..:/workspace", "-w", "/workspace/Examples/SAM", baseImage, "bash", "-cl", buildCommand],

https://www.hackingwithswift.com/swift/5.4/result-builders
https://github.com/carson-katri/awesome-result-builders#server-side
https://github.com/apple/swift-evolution/blob/main/proposals/0289-result-builders.md
https://developer.apple.com/videos/play/wwdc2021/10253/

From 
https://github.com/apple/swift-package-manager/compare/main...tomerd:swift-package-manager:feature/manifest2-poc

https://forums.swift.org/t/pre-pitch-swiftpm-manifest-based-on-result-builders/53457

```
public class Package: Codable {
    public var modules: [Module]
    public var dependencies: [Dependency]
    public var minimumDeploymentTargets: [DeploymentTarget]

    public init() {
        self.modules = []
        self.dependencies = []
        self.minimumDeploymentTargets = []
        // register for serialization
        __packages.append(self)
        // FIXME: get rid of atexit in favor of more reliable solution
        atexit {
            if CommandLine.arguments.first?.contains("-manifest") ?? false {
                try! PackageSerializer.serialize(__packages.last!)
            }
        }
    }
```

```
#if canImport(Glibc)
@_implementationOnly import Glibc
#elseif os(iOS) || os(macOS) || os(tvOS) || os(watchOS)
@_implementationOnly import Darwin.C
#elseif os(Windows)
@_implementationOnly import ucrt
@_implementationOnly import struct WinSDK.HANDLE
#endif
import Foundation

// Adds an main handler to cause the package's JSON representation
// to be written to a file when executed as a program.
// Emitting it to a separate file descriptor from stdout
// keeps any of the manifest's stdout output from interfering with it.
//
// Warning:  The `-fileno` flag is a contract between PackageDescription
// and libSwiftPM, and since different versions of the two can be used
// together, it isn't safe to rename or remove it.
//
// Note: `-fileno` is not viable on Windows.  Instead, we pass the file
// handle through the `-handle` option.

struct PackageSerializer {
    static func serialize(_ package: Package) throws {
        #if os(Windows)
        guard let index = CommandLine.arguments.firstIndex(of: "-handle"), let handleId = Int(CommandLine.arguments[index + 1], radix: 16) else {
            throw PackageSerializerErrors.invalidArguments
        }
        // write serialized package to the file
        guard let handle = HANDLE(bitPattern: handleId) else {
            throw PackageSerializerErrors.invalidFileHandle
        }
        // NOTE: `_open_osfhandle` transfers ownership of the HANDLE to the file
        // descriptor. DO NOT invoke `CloseHandle` on `hFile`.
        let fd: CInt = _open_osfhandle(Int(bitPattern: handle), _O_APPEND)
        // NOTE: `_fdopen` transfers ownership of the file descriptor to the
        // `FILE *`.  DO NOT invoke `_close` on the `fd`.
        guard let filePipe = _fdopen(fileDescriptor, "w") else {
            _close(fileDescriptor)
            throw PackageSerializerErrors.failedOpeningFile
        }
        defer {
            fclose(filePipe)
        }

        fputs(try package.toJSON(), filePipe)
        #else
        guard let index = CommandLine.arguments.firstIndex(of: "-fileno"), let fileDescriptorId = Int32(CommandLine.arguments[index + 1]) else {
            throw PackageSerializerErrors.invalidArguments
        }
        // write serialized package to the file
        guard let fileDescriptor = fdopen(fileDescriptorId, "w") else {
            throw PackageSerializerErrors.failedOpeningFile
        }
        defer {
            fclose(fileDescriptor)
        }

        fputs(try package.toJSON(), fileDescriptor)
        #endif
    }
}

extension Package {
    fileprivate func toJSON() throws -> String {
        struct Output: Encodable {
            let version = "1.0" // manifest JSON version
            let package: Package
        }

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        let data = try encoder.encode(Output(package: self))
        return String(data: data, encoding: .utf8)!
    }
}

private enum PackageSerializerErrors: Error {
    case unknownPackage
    case invalidArguments
    case invalidFileHandle
    case failedOpeningFile
}
```

Check https://forums.swift.org/t/pre-pitch-swiftpm-manifest-based-on-result-builders/53457/5
to remove top level class 

```
import PackageManifest

Package {
  ...
}
```

```
// Within PackageManifest module

public var package: Package?

@resultBuilder
struct Package {

  @discardableResult
  static func buildFinalResult(_ p: Package) -> Package {
    package = p
  }
}
```