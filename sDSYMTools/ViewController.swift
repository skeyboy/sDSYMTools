//
//  ViewController.swift
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

public class Info: InfoProtocol {
    var uuidInfos: [UUIDInfo]?
    var archiveType: ArchiveType {

        return .default
    }
}

extension Info {
    var fileName: String {
        if self.archiveType == .dSYM {
            return (self as! DSYMInfo).dSYMFileName!
        }
        if self.archiveType == .xcarchive {
            return (self as! ArchiveInfo).archiveFileName!
        }
        return ""
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


class ViewController: NSViewController {
    var archiveFilesInfo: [Info] = [Info]()

    @IBOutlet weak var errorMessageView: NSTextField!
    @IBOutlet weak var errorMemoryAddressLabel: NSTextField!
    @IBOutlet weak var selectedSlideAddressLabel: NSTextField!
    @IBOutlet weak var selectedUUIDLabel: NSTextField!
    @IBOutlet weak var radioBox: NSBox!
    @IBOutlet weak var archiveFilesTableView: NSTableView!
    var selectedArchiveInfo: Info?
    var selectedUUIDInfo: UUIDInfo?

    override func viewDidLoad() {
        super.viewDidLoad()

        handleArchiveFileWithPaths(self.allDSYMFilePath())

        // Do any additional setup after loading the view.
        self.view.window?.registerForDraggedTypes([NSColorPboardType, NSFilenamesPboardType])
        archiveFilesTableView.delegate = self
        archiveFilesTableView.dataSource = self
        self.archiveFilesTableView.reloadData()

    }

    @IBAction func analyseInfo(_ sender: Any) {
        if self.selectedArchiveInfo == nil {
            return
        }
        if self.selectedUUIDInfo == nil {
            return
        }
        if self.selectedSlideAddressLabel.stringValue == "" || self.errorMemoryAddressLabel.stringValue == "" {
            return
        }
        let commandOCString = String.init(format: "xcrun atos -arch %@ -o \"%@\" -l %@ %@", (self.selectedUUIDInfo?.arch)!, (self.selectedUUIDInfo?.executableFilePath)!, self.selectedSlideAddressLabel.stringValue, self.errorMemoryAddressLabel.stringValue)

        let result = self.runCommand(commandToRun: commandOCString)
        self.errorMessageView.stringValue = result

    }

    override var representedObject: Any? {

        didSet {
            // Update the view, if already loaded.
        }
    }


}

extension ViewController {
    func allDSYMFilePath() -> [NSURL] {

        let fileManager = FileManager.default
        let archivesPath = NSHomeDirectory().appending("/Library/Developer/Xcode/Archives/")
        let bundleURL = NSURL(fileURLWithPath: archivesPath)
        //使用enumeration遍历
        let enumerator = fileManager.enumerator(at: bundleURL.filePathURL!, includingPropertiesForKeys: [URLResourceKey.nameKey, URLResourceKey.isDirectoryKey], options: [FileManager.DirectoryEnumerationOptions.skipsHiddenFiles]) { (url, error) -> Bool in

            print("\(url) \(error)")
            return true
        }
        var fast = enumerator?.makeIterator()
        var dysmFilePaths = [NSURL]()
        while let next: NSURL = fast?.next() as? NSURL {


            let xcArchive = XcArchiveType.init(rawValue: next.pathExtension!)

            if xcArchive == .xcarchive || xcArchive == .dSYM {
                dysmFilePaths.append(next)
            }
        }

        return dysmFilePaths
    }


    func handleArchiveFileWithPaths(_ paths: [NSURL]) -> Void {

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

/*解析对应的archive文件*/
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

/*通用的shell交互*/
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

/*解析dsym文件*/
    func formatDSYM(_ archiveInfo: ArchiveInfo) -> Void {
        let pattern = "(?<=\\()[^}]*(?=\\))"


        let reg: NSRegularExpression = try! NSRegularExpression.init(pattern: pattern
            , options: [NSRegularExpression.Options.caseInsensitive])
        let commandString: String = String.init(format: "dwarfdump --uuid \"%@\" ", archiveInfo.dSYMFilePath!)


        let uuidsString = self.runCommand(commandToRun: commandString) as NSString

        let uuids: [String] = (uuidsString as String).components(separatedBy: "\n")


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

/*重置一些现实UI的信息*/
    func resetPreInformation() {
        self.selectedSlideAddressLabel.stringValue = ""
        self.errorMemoryAddressLabel.stringValue = ""
        
        self.selectedUUIDLabel.stringValue = ""
        self.errorMessageView.stringValue = ""
        self.selectedArchiveInfo = nil
    }


}

extension ViewController: NSTableViewDelegate {
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let archiveInfo = self.archiveFilesInfo[row]
        let identifier = tableColumn?.identifier
        let view: NSView = tableView.make(withIdentifier: identifier!, owner: self)!
        let subViews = view.subviews
        if subViews.count > 0 {
            if identifier! == "name" {
                let textField: NSTextField = subViews[0] as! NSTextField
                textField.stringValue = archiveInfo.fileName
            }
        }

        return view
    }

    func tableViewSelectionDidChange(_ notification: Notification) {
        resetPreInformation()
        let row = (notification.object as! NSTableView).selectedRow

        if let contentView = self.radioBox.contentView {
            if contentView.subviews.count > 0 {
                for sub in contentView.subviews {
                    sub.removeFromSuperview()
                }
            }
        }

        if row == -1 {

            return
        }

        self.selectedArchiveInfo = self.archiveFilesInfo[row]
        
        if let uuidInfos = self.selectedArchiveInfo?.uuidInfos {
            var index = 0

            for info in uuidInfos {
                let radioButton = NSButton.init(frame: NSRect(x: 10, y: index * 50, width: 100, height: 45))
                radioButton.setButtonType(NSButtonType.radio)
                radioButton.title = info.arch!
                radioButton.tag = index
                radioButton.action = #selector(radioButtonAction(sender:))
                self.radioBox.contentView?.addSubview(radioButton)
                index += 1
            }
        }
    }

/*
选取对应的CPU类型
*/
    @objc func radioButtonAction(sender: NSButton) {
        self.selectedUUIDInfo = nil
        if sender.tag == -1 {
            return
        }
        let uuidInfo = self.selectedArchiveInfo!.uuidInfos![sender.tag]
        self.selectedUUIDLabel.stringValue = uuidInfo.uuid ?? ""
        self.selectedSlideAddressLabel.stringValue = uuidInfo.defaultSlideAddress ?? ""
self.selectedUUIDInfo = uuidInfo
    }

    @objc public func showAboutMe() {
        
        performSegue(withIdentifier: "show_about_me", sender: nil)
    }
}

extension ViewController: NSTableViewDataSource {
    func numberOfRows(in tableView: NSTableView) -> Int {
        return self.archiveFilesInfo.count
    }

    func tableView(_ tableView: NSTableView, objectValueFor tableColumn: NSTableColumn?, row: Int) -> Any? {
        let archiveInfo = self.archiveFilesInfo[row]
        return archiveInfo.fileName
    }


}
