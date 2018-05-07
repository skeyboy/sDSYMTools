//
//  AboutViewController.swift
//  sDSYMTools
//
//  Created by 李雨龙 on 2018/5/4.
//  Copyright © 2018年 李雨龙. All rights reserved.
//

import Cocoa

class AboutViewController: NSViewController {
    @IBOutlet weak var github: NSTextField!
    func hyperlinkFrom(_ innerStrig:String , withURL url:URL ) -> NSAttributedString {
        let attrString = NSMutableAttributedString.init(string: innerStrig)
        attrString.beginEditing()
       let rang = NSMakeRange(0, attrString.length)
        
        attrString.addAttribute(NSLinkAttributeName, value: url, range: rang)
        attrString.addAttribute(NSForegroundColorAttributeName, value: NSColor.red, range: rang)
        attrString.addAttribute(NSUnderlineStyleAttributeName, value: NSNumber.init(value: Int8(NSUnderlineStyle.styleSingle.rawValue)), range: rang)
        
        attrString.endEditing()
        
        return attrString
    }
    @IBAction func cancel(_ sender: Any) {
        
        
        //结束sheet可以让父窗口获取焦点
self.view.window?.sheetParent?.endSheet(self.view.window!, returnCode: NSModalResponseOK)
    }
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do view setup here.
        self.title = "关于"
        self.github.isEnabled = true
        
        let githubURL = URL(string: "https://github.com/skeyboy/sDSYMTools")
        
        self.github.allowsEditingTextAttributes = true
        
        github.attributedStringValue = hyperlinkFrom("SkeyBoy", withURL: githubURL!)

    }
    
}
