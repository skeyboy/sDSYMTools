//
//  ViewController.swift
//  sDSYMTools
//
//  Created by 李雨龙 on 2018/5/3.
//  Copyright © 2018年 李雨龙. All rights reserved.
//

import Cocoa

class ViewController: NSViewController {
    
    @IBOutlet weak var archiveFilesTableView: NSTableView!

    override func viewDidLoad() {
        super.viewDidLoad()


        // Do any additional setup after loading the view.
        self.view.window?.registerForDraggedTypes([NSColorPboardType, NSFilenamesPboardType])
        
        
    }

    override var representedObject: Any? {

        didSet {
            // Update the view, if already loaded.
        }
    }


}

