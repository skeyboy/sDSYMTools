//
//  MainWindowController.swift
//  sDSYMTools
//
//  Created by 李雨龙 on 2018/5/3.
//  Copyright © 2018年 李雨龙. All rights reserved.
//

import Cocoa
import Foundation

public enum XcArchiveType: String {


    case xcarchive = "xcarchive"
    case dSYM = "app.dSYM"
    case `default` = ""
}


public struct UUIDInfo {
    var arch: String?
    var defaultSlideAddress: String?
    var uuid: String?
    var executableFilePath: String?
}


typealias ArchiveType = XcArchiveType

protocol InfoProtocol {
    var archiveType: ArchiveType { get }
}

public class Info {
    var uuidInfos: [UUIDInfo]?
    var archiveType: ArchiveType {

        return .default
    }
}

public class ArchiveInfo: DSYMInfo {
    var archiveFileName: String?
    var archiveFilePath: String?

    override var archiveType: ArchiveType {
        return .xcarchive
    }

}

public class DSYMInfo: Info {
    var dSYMFilePath: String?
    var dSYMFileName: String?
    override var archiveType: ArchiveType {
        return .dSYM
    }
}


class MainWindowController: NSWindowController {

    var archiveFilesInfo: [Info] = [Info]()

    ///Mark 遍历archive文件的主目录
    func allDSYMFilePath() -> [NSURL] {

        let fileManager = FileManager.default
        let archivesPath = NSHomeDirectory().appending("/Library/Developer/Xcode/Archives/")
        let bundleURL = NSURL(fileURLWithPath: archivesPath)
        let enumerator = fileManager.enumerator(at: bundleURL.filePathURL!, includingPropertiesForKeys: [URLResourceKey.nameKey, URLResourceKey.isDirectoryKey], options: [FileManager.DirectoryEnumerationOptions.skipsHiddenFiles]) { (url, error) -> Bool in

            print("\(url) \(error)")
            return true
        }
        let fast = enumerator?.makeIterator()
        var dysmFilePaths = [NSURL]()
        while let next: NSURL = fast?.next() as? NSURL {

            // print(next)
            //print(type(of: next))

            let xcArchive = XcArchiveType.init(rawValue: next.pathExtension!)

            if xcArchive == .xcarchive || xcArchive == .dSYM {
                dysmFilePaths.append(next)
            }
        }

        return dysmFilePaths
    }


    override func windowDidLoad() {
        super.windowDidLoad()

        // Implement this method to handle any initialization after your window controller's window has been loaded from its nib file.

        handleArchiveFileWithPaths(self.allDSYMFilePath())

    }

    func handleArchiveFileWithPaths(_ paths: [NSURL]) -> Void {

        print(paths)

        for filePath in paths {
            let fileName = filePath.lastPathComponent

            var info: Info = Info()
            let fileType = XcArchiveType.init(rawValue: filePath.pathExtension!)

            switch fileType! {
            case .xcarchive:
                info = ArchiveInfo()
                let arInfo: ArchiveInfo = info as! ArchiveInfo
                arInfo.archiveFileName = fileName
                arInfo.archiveFilePath = filePath.absoluteString!.removingPercentEncoding

                self.formatArchiveInfo(arInfo)

                break
            case .dSYM:
                info = DSYMInfo()

                let dsInfo: DSYMInfo = info as! DSYMInfo
                dsInfo.dSYMFileName = fileName
                dsInfo.dSYMFilePath = filePath.absoluteString
                self.formatDSYM(info as! ArchiveInfo)

                break
            case .default:
                print("Error 没有")
            }
            archiveFilesInfo.append(info)
            print(archiveFilesInfo)
        }
    }

    func formatArchiveInfo(_ archiveInfo: ArchiveInfo) -> Void {
        var dSYMsDirectoryPath = archiveInfo.archiveFilePath!
        dSYMsDirectoryPath.append("dSYMs")

        let url = URL.init(fileURLWithPath: dSYMsDirectoryPath.description.components(separatedBy: "//").last!)
//print(url)
        let resourceKeys = [URLResourceKey.pathKey, .fileResourceTypeKey, .isDirectoryKey, .isPackageKey]

        do {
            let dSYMsSubFiles = try FileManager.default.contentsOfDirectory(at: url,
                includingPropertiesForKeys: resourceKeys, options: [.skipsHiddenFiles, .skipsPackageDescendants])
            for fileURLs in dSYMsSubFiles {
                if fileURLs.lastPathComponent.hasSuffix("app.dSYM") {
                    archiveInfo.dSYMFilePath = fileURLs.relativePath
                    archiveInfo.dSYMFileName = fileURLs.lastPathComponent
                }
            }
            self.formatDSYM(archiveInfo)
        } catch let e {
            print(e)
        }


    }

    func runCommand(commandToRun command: String) -> String {
        let task: Process = Process()
        task.launchPath = "/bin/sh"
        let args = ["-c", String.init(format: "%@", command)]
        task.arguments = args

        let pipe = Pipe.init()
        task.standardOutput = pipe
        let fileHandle = pipe.fileHandleForReading
        task.launch()
        let data = fileHandle.readDataToEndOfFile()
        let output = String.init(data: data, encoding: String.Encoding.utf8)
        return output!
    }

    func formatDSYM(_ archiveInfo: ArchiveInfo) -> Void {
        let pattern = "(?<=\\()[^}]*(?=\\))"


        let reg: NSRegularExpression = try! NSRegularExpression.init(pattern: pattern
            , options: [NSRegularExpression.Options.caseInsensitive])
        let commandString: String = String.init(format: "dwarfdump --uuid \"%@\" ", archiveInfo.dSYMFilePath!)


        let uuidsString = self.runCommand(commandToRun: commandString) as NSString

        let uuids : [String] = ( uuidsString as String).components(separatedBy: "\n")
        

        var uuidInfos = [UUIDInfo]()

        for uuidString in uuids {
            if uuidsString == "" {
                continue
            }
            let match: [NSTextCheckingResult] = reg.matches(in: uuidsString as String, options: [NSRegularExpression.MatchingOptions.reportCompletion], range: NSRange.init(location: 0, length: uuidsString.length))


            if (match.count == 0) {
                continue
            }


            for result in match {

                let range = result.range
                if range.length < 6 {
                    continue
                }
                var uuidInfo = UUIDInfo()
               
                let uuidOCString = uuidString as NSString
                if uuidOCString == "" {
                    continue
                }
                uuidInfo.arch = uuidOCString.substring(with: range)
                uuidInfo.uuid = uuidOCString.substring(with: NSMakeRange(6, range.location - 6 - 2))
                uuidInfo.executableFilePath = uuidOCString.substring(with:
                NSMakeRange(range.location + range.length + 2,
                    uuidOCString.length - (range.location + range.length + 2))
                )
uuidInfos.append(uuidInfo)

            }
            archiveInfo.uuidInfos = uuidInfos

        }


    }

}
