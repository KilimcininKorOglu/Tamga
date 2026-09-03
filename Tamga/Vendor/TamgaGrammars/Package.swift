// swift-tools-version:5.9
import PackageDescription

// Vendored tree-sitter grammars for Tamga.
// Sources are copied from the upstream tree-sitter grammar repos. Unlike the
// upstream Package.swift files (which include scanner.c via a CWD-relative
// `FileManager.fileExists` check that fails under Xcode and drops the external
// scanner), each target here lists parser.c AND scanner.c explicitly so the
// external scanner symbols always link.
let package = Package(
    name: "TamgaGrammars",
    platforms: [.macOS(.v13)],
    products: [
        .library(
            name: "TamgaGrammars",
            targets: [
                "TreeSitterHTML",
                "TreeSitterJavaScript",
                "TreeSitterCSS",
                "TreeSitterPython",
                "TreeSitterJSON",
                "TreeSitterBash",
                "TreeSitterYAML",
                "TreeSitterXML",
                "TreeSitterSwift",
                "TreeSitterSQL",
                "TreeSitterPHP",
                "TreeSitterGo",
                "TreeSitterRust",
                "TreeSitterC",
                "TreeSitterJava",
                "TreeSitterCPP",
            ]
        ),
    ],
    targets: [
        .target(
            name: "TreeSitterHTML",
            path: "Sources/TreeSitterHTML",
            sources: ["src/parser.c", "src/scanner.c"],
            resources: [.copy("queries")],
            publicHeadersPath: "bindings/swift",
            cSettings: [.headerSearchPath("src")]
        ),
        .target(
            name: "TreeSitterJavaScript",
            path: "Sources/TreeSitterJavaScript",
            sources: ["src/parser.c", "src/scanner.c"],
            resources: [.copy("queries")],
            publicHeadersPath: "bindings/swift",
            cSettings: [.headerSearchPath("src")]
        ),
        .target(
            name: "TreeSitterCSS",
            path: "Sources/TreeSitterCSS",
            sources: ["src/parser.c", "src/scanner.c"],
            resources: [.copy("queries")],
            publicHeadersPath: "bindings/swift",
            cSettings: [.headerSearchPath("src")]
        ),
        .target(
            name: "TreeSitterPython",
            path: "Sources/TreeSitterPython",
            sources: ["src/parser.c", "src/scanner.c"],
            resources: [.copy("queries")],
            publicHeadersPath: "bindings/swift",
            cSettings: [.headerSearchPath("src")]
        ),
        .target(
            name: "TreeSitterJSON",
            path: "Sources/TreeSitterJSON",
            sources: ["src/parser.c"],
            resources: [.copy("queries")],
            publicHeadersPath: "bindings/swift",
            cSettings: [.headerSearchPath("src")]
        ),
        .target(
            name: "TreeSitterBash",
            path: "Sources/TreeSitterBash",
            sources: ["src/parser.c", "src/scanner.c"],
            resources: [.copy("queries")],
            publicHeadersPath: "bindings/swift",
            cSettings: [.headerSearchPath("src")]
        ),
        .target(
            name: "TreeSitterYAML",
            path: "Sources/TreeSitterYAML",
            sources: ["src/parser.c", "src/scanner.c"],
            resources: [.copy("queries")],
            publicHeadersPath: "bindings/swift",
            cSettings: [.headerSearchPath("src")]
        ),
        .target(
            name: "TreeSitterXML",
            path: "Sources/TreeSitterXML",
            sources: ["src/parser.c", "src/scanner.c"],
            resources: [.copy("queries")],
            publicHeadersPath: "bindings/swift",
            cSettings: [.headerSearchPath("src")]
        ),
        .target(
            name: "TreeSitterSwift",
            path: "Sources/TreeSitterSwift",
            sources: ["src/parser.c", "src/scanner.c"],
            resources: [.copy("queries")],
            publicHeadersPath: "bindings/swift",
            cSettings: [.headerSearchPath("src")]
        ),
        .target(
            name: "TreeSitterSQL",
            path: "Sources/TreeSitterSQL",
            sources: ["src/parser.c", "src/scanner.c"],
            resources: [.copy("queries")],
            publicHeadersPath: "bindings/swift",
            cSettings: [.headerSearchPath("src")]
        ),
        .target(
            name: "TreeSitterPHP",
            path: "Sources/TreeSitterPHP",
            sources: ["src/parser.c", "src/scanner.c"],
            resources: [.copy("queries")],
            publicHeadersPath: "bindings/swift",
            cSettings: [.headerSearchPath("src")]
        ),
        .target(
            name: "TreeSitterGo",
            path: "Sources/TreeSitterGo",
            sources: ["src/parser.c"],
            resources: [.copy("queries")],
            publicHeadersPath: "bindings/swift",
            cSettings: [.headerSearchPath("src")]
        ),
        .target(
            name: "TreeSitterRust",
            path: "Sources/TreeSitterRust",
            sources: ["src/parser.c", "src/scanner.c"],
            resources: [.copy("queries")],
            publicHeadersPath: "bindings/swift",
            cSettings: [.headerSearchPath("src")]
        ),
        .target(
            name: "TreeSitterC",
            path: "Sources/TreeSitterC",
            sources: ["src/parser.c"],
            resources: [.copy("queries")],
            publicHeadersPath: "bindings/swift",
            cSettings: [.headerSearchPath("src")]
        ),
        .target(
            name: "TreeSitterJava",
            path: "Sources/TreeSitterJava",
            sources: ["src/parser.c"],
            resources: [.copy("queries")],
            publicHeadersPath: "bindings/swift",
            cSettings: [.headerSearchPath("src")]
        ),
        .target(
            name: "TreeSitterCPP",
            path: "Sources/TreeSitterCPP",
            sources: ["src/parser.c", "src/scanner.c"],
            resources: [.copy("queries")],
            publicHeadersPath: "bindings/swift",
            cSettings: [.headerSearchPath("src")]
        ),
    ],
    cLanguageStandard: .c11
)
