//
//  OpenHaystack – Tracking personal Bluetooth devices via Apple's Find My network
//
//  Copyright © 2021 Secure Mobile Networking Lab (SEEMOO)
//  Copyright © 2021 The Open Wireless Link Project
//
//  SPDX-License-Identifier: AGPL-3.0-only
//

import AppKit
import Foundation

class SavePanel: NSObject, NSOpenSavePanelDelegate {

    static let shared = SavePanel()

    var fileToSave: Data?
    var fileExtension: String?
    var panel: NSSavePanel?

    func saveFile(file: Data, fileExtension: String) {
        self.fileToSave = file
        self.fileExtension = fileExtension

        self.panel = NSSavePanel()
        self.panel?.delegate = self
        self.panel?.title = "Export Find My Locations"
        self.panel?.prompt = "Export"
        self.panel?.nameFieldLabel = "Find My Locations"
        self.panel?.nameFieldStringValue = "findMyLocations.plist"
        self.panel?.allowedFileTypes = ["plist"]

        let result = self.panel?.runModal()

        if result == NSApplication.ModalResponse.OK {
            // Save file
            let fileURL = self.panel?.url
            // swiftlint:disable force_try
            try! self.fileToSave?.write(to: fileURL!)
        }

    }

    func panel(_ sender: Any, userEnteredFilename filename: String, confirmed okFlag: Bool) -> String? {
        guard okFlag else { return nil }

        return filename
    }

}
