//
//  OpenHaystack – Tracking personal Bluetooth devices via Apple's Find My network
//
//  Copyright © 2021 Secure Mobile Networking Lab (SEEMOO)
//  Copyright © 2021 The Open Wireless Link Project
//
//  SPDX-License-Identifier: AGPL-3.0-only
//

import SwiftUI
import Dispatch
import Cocoa
import Foundation

struct OFFetchReportsMainView: View {

  @Environment(\.findMyController) var findMyController
  
  @State var targetedDrop: Bool = false
  @State var error: Error?
  @State var showData = false
  @State var loading = false
  @State var messageIDToFetch: UInt32 = 0

  @State var searchPartyToken: Data?
  @State var searchPartyTokenString: String = ""
  @State var modemID: UInt32 = 0
  @State var modemIDString: String = ""
  @State var chunkLength: UInt32 = 0
  @State var chunkLengthString: String = ""
  @State var keyPlistFile: Data?

  @State var showModemPrompt = false
  @State var repeatTime: Int = 0
  @State var messageStartFrom: Int = 0
  @State var numMessages: Int = 1
  
  @State var isRepeatingFetch: Bool = true
  @State var timer: Timer?
  
  @State var logFilePath: String = ""
  @State var fileHandle: FileHandle?
  
  func openFolderDialog() {
    let openPanel = NSOpenPanel();
    openPanel.canChooseDirectories = true; // Allow folder selection
    openPanel.canChooseFiles = false; // Don't allow file selection
    openPanel.allowsMultipleSelection = false; // Allow only one folder selection
    openPanel.prompt = "Select Folder";
      
      openPanel.begin { (result) in
          if result == .OK {
              if let selectedURL = openPanel.urls.first {
                let selectedFolderPath = selectedURL.path;
                  // Use selectedFolderPath as the path to the selected folder
                self.logFilePath = selectedFolderPath + "/log-" + String(Int(Date().timeIntervalSince1970)) + ".txt"
              }
          }
      }
  }
  
  func logAndPrint(_ text: String, fileHandle: FileHandle) {
    fileHandle.seekToEndOfFile()
    
    // Convert the string to data and write it to the file
    if let data = (text+"\n").data(using: .utf8) {
        fileHandle.write(data)
        print(text)
    } else {
        print("Error converting string to data")
    }
  }
  
  var modemIDView: some View {
      VStack {
          HStack {
            Text("Please insert the modem id that you want to fetch data for:")
            TextField("4 byte hex string, e.g. DE AD BE EF", text: self.$modemIDString).frame(width: 250)
          }
        
          HStack {
            Text("Repeat Time (s):")
            TextField("Enter Repeat Time", value: self.$repeatTime, formatter: NumberFormatter()).frame(width: 100)
          }
        
          HStack {
            Text("Start from message:")
            TextField("Message start from", value: self.$messageStartFrom, formatter: NumberFormatter()).frame(width: 100)
          }

          HStack {
            Text("Number of Messages:")
            TextField("Enter Number of Messages", value: self.$numMessages, formatter: NumberFormatter()).frame(width: 100)
          }
        
          HStack {
            Text("Chunk Length (1-8 bits):")
            TextField("Length of chunk in bits (1-8)", text: self.$chunkLengthString).frame(width: 250)
          }

          VStack {
            Text("Log file: " + logFilePath)

            Button(
              action: {
                openFolderDialog();
              },
              label: {
                Text("Select Log Folder");
              }
            )
          }
        
          Divider()
        
          HStack {
            Button(
              action: {
                /*
                //generating a bunch of keys
                let staticPrefix: [UInt8] = [0xba, 0xbe]
                let zeroPadding: [UInt8] = [0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00]
                var count: UInt16 = 0
                var validCounter: UInt8 = 0
                var keyTest = [UInt8]()
                while count < 65535 {
                    keyTest = staticPrefix + byteArray(from: modemID)
                    keyTest += byteArray(from: validCounter) + zeroPadding + byteArray(from: count)
                    var hexKeyTest = String(format:"%02X", keyTest[0])
                    for i in 1..<keyTest.count{
                        hexKeyTest += " " + String(format:"%02X", keyTest[i])
                    }
                    if BoringSSL.isPublicKeyValid(Data(keyTest)) == 0 {
                        validCounter += 1
                    } else {
                        count += 1
                        validCounter = 0
                    }
                }
                */
                
                guard let parsedModemID = UInt32(self.modemIDString.replacingOccurrences(of: " ", with: "", options: NSString.CompareOptions.literal, range: nil), radix: 16) else { return }
                guard let parsedChunkLength = UInt32(self.chunkLengthString.replacingOccurrences(of: " ", with: "", options: NSString.CompareOptions.literal, range: nil), radix: 10) else { return }
                
                self.modemID = parsedModemID
                self.chunkLength = parsedChunkLength
                self.isRepeatingFetch = repeatTime > 0
                
                if let fileHandle = FileHandle(forWritingAtPath: logFilePath) {
                    // The file already exists, so use the existing file handle.
                    self.fileHandle = fileHandle
                } else {
                    // The file doesn't exist, so create it.
                    if FileManager.default.createFile(atPath: logFilePath, contents: nil, attributes: nil) {
                        if let fileHandle = FileHandle(forWritingAtPath: logFilePath) {
                            self.fileHandle = fileHandle
                        } else {
                            // Handle the case where the file still cannot be opened.
                            print("Failed to open created log file at path: \(logFilePath)")
                            return
                        }
                    } else {
                        // Handle the case where the file cannot be created.
                        print("Failed to create log file at path: \(logFilePath)")
                        return
                    }
                }
                
                logAndPrint("Parsed Modem ID: \(parsedModemID); " + String(parsedModemID, radix: 16), fileHandle: self.fileHandle!)
                logAndPrint("Chunk Length: \(parsedChunkLength); " + String(parsedChunkLength, radix: 16), fileHandle: self.fileHandle!)
                logAndPrint("Time to repeat search, in seconds: " + String(repeatTime), fileHandle: self.fileHandle!)
                logAndPrint("Number of messages to automatically fetch: " + String(numMessages), fileHandle: self.fileHandle!)
                
                self.findMyController.clearMessages()
                
                loadMultiMessage(modemID: parsedModemID, startFrom: messageStartFrom, numMessages: numMessages, chunkLength: chunkLength)
                isRepeatingFetch = repeatTime > 0
                
                if self.repeatTime > 0 {
                    // Convert repeatTime to TimeInterval
                    let repeatTimeInterval: TimeInterval = TimeInterval(self.repeatTime)
                    
                    // Start the timer
                    self.timer = Timer.scheduledTimer(withTimeInterval: repeatTimeInterval, repeats: true) { _ in
                        // Call your function when the timer fires
                      if self.isRepeatingFetch {
                        self.loadMultiMessage(modemID: self.modemID, startFrom: self.messageStartFrom, numMessages: self.numMessages, chunkLength: self.chunkLength)
                      }
                    }
                }
                
                self.showData = true
                self.showModemPrompt = false
                
              },
              label: {
                Text("Download data")
              })
        }
    }
  }
  
  var loadingView: some View {
    VStack {
      Text("Downloading and decoding message #\(self.messageIDToFetch)...")
        .font(Font.system(size: 32, weight: .bold, design: .default))
        .padding()
    }
  }
        
  var dataView: some View {
    VStack {
           HStack {
               // Text("Result")
               Spacer()
                 Button(
                   action: {
                     self.showData = false
                     self.showModemPrompt = true
                     self.isRepeatingFetch = false
                   },
                   label: {
                     Text("Fetch Every: " + String(repeatTime) + "s")
                   }).padding(.top, 5).padding(.trailing, 5)
                 
                  Button(
                     action: {
                       self.isRepeatingFetch = !self.isRepeatingFetch
                       print("Auto Refetch:" + String(isRepeatingFetch))
                     },
                     label: {
                       Text(isRepeatingFetch ? "Stop Fetching" : "Continue Fetching")
                   }).padding(.top, 5).padding(.trailing, 5)
                 
                  Button(
                    action: {
                      self.showData = false
                      self.showModemPrompt = true
                      self.isRepeatingFetch = false
                    },
                    label: {
                      Text("ID: 0x\(String(self.findMyController.modemID, radix: 16))")
                    }).padding(.top, 5).padding(.trailing, 5)
           }
           Divider()
      ScrollView {
        ForEach(0...max(300, self.findMyController.messages.count+1), id: \.self) { i in
          if  self.findMyController.messages[UInt32(i)] != nil {
            HStack {
              Text("#\(self.findMyController.messages[UInt32(i)]!.messageID)").font(.system(size: 14, design: .monospaced)).frame(width: 45)
              Text(self.findMyController.messages[UInt32(i)]!.decodedStr ?? "<None>").font(.system(size: 14, design: .monospaced))
              
              Spacer()
              Button(
                action: {
                  self.loadMessage(modemID: self.modemID, messageID: self.findMyController.messages[UInt32(i)]!.messageID, chunkLength: self.chunkLength)
                },
                label: {
                  Text("Reload message")
                })
            }
          } else {
            
            Button(
              action: {
                self.loadMessage(modemID: self.modemID, messageID: UInt32(i), chunkLength: self.chunkLength)
              },
              label: {
                Text("Load message #\(i)")
              })
            //Spacer()
            
            
          }
        }
      }
     }
  }

  // This view is shown if the search party token cannot be accessed from keychain
  var missingSearchPartyTokenView: some View {
    VStack {
      Text("Search Party token could not be fetched")
      Text("Please paste the search party token below after copying it from the macOS Keychain.")
      Text("The item that contains the key can be found by searching for: ")
      Text("com.apple.account.DeviceLocator.search-party-token")
        .font(.system(Font.TextStyle.body, design: Font.Design.monospaced))

      TextField("Search Party Token", text: self.$searchPartyTokenString)

      Button(
        action: {
          if !self.searchPartyTokenString.isEmpty,
            let file = self.keyPlistFile,
            let searchPartyToken = self.searchPartyTokenString.data(using: .utf8)
          {
            self.searchPartyToken = searchPartyToken
            //self.downloadAndDecryptLocations(with: file, searchPartyToken: searchPartyToken)
          }
        },
        label: {
          Text("Download reports")
        })
    }
  }
  
  var body: some View {
    GeometryReader { geo in
      if self.loading {
        self.dataView
      } else if self.showModemPrompt {
        self.modemIDView
      }
      else if self.showData {
        self.dataView
      } else {
        self.modemIDView
          .frame(width: geo.size.width, height: geo.size.height)
      }
    }
  }

  // swiftlint:disable identifier_name
  func getDataForModem(modemID: UInt32) -> Bool {
        print("Retrieving data")
        print(modemID)
        
            AnisetteDataManager().requestAnisetteData { result in
            switch result {
            case .failure(_):
                print("AnsietteDataManager failed.")
            case .success(let accountData):

                guard let token = accountData.searchPartyToken,
                    token.isEmpty == false
                else {
                    print("Fail token")
                    return
                }
                print("Fetching data")
                print(token)
                self.downloadAndDecodeData(modemID: modemID, messageID: UInt32(0), chunkLength: UInt32(8), searchPartyToken: token)

            }
        }
    return true
  }
  
  func loadMultiMessage(modemID: UInt32, startFrom: Int, numMessages: Int, chunkLength: UInt32) {
    // TODO: Make this run parellel
    for i in startFrom...startFrom + numMessages - 1 {
      self.loadMessage(modemID: modemID, messageID: UInt32(i), chunkLength: chunkLength)
    }
  }

  // swiftlint:disable identifier_name
  func loadMessage(modemID: UInt32, messageID: UInt32, chunkLength: UInt32) -> Bool {
      self.messageIDToFetch = messageID
      print("Retrieving data")
      
      AnisetteDataManager().requestAnisetteData { result in
        switch result {
          case.failure(_):
              print("AnsietteDataManager failed.")
          case.success(let accountData):
            guard let token = accountData.searchPartyToken,
                token.isEmpty == false
            else {
                print("Fail token")
                return
            }
            print("Fetching data")
            print(token)
            self.downloadAndDecodeData(modemID: modemID, messageID: messageID, chunkLength: chunkLength, searchPartyToken: token)
        }
      }
    return true
  }

  func downloadAndDecodeData(modemID: UInt32, messageID: UInt32, chunkLength: UInt32, searchPartyToken: Data) {
    self.loading = true
    print("modemID: " + String(modemID))
    print("messageID: " + String(messageID))
    print("chunkLength: " + String(chunkLength))

    self.findMyController.fetchMessage(
      for: modemID, message: messageID, chunk: chunkLength, with: searchPartyToken, logger: self.fileHandle!,
      completion: { error in
        // Check if an error occurred
        guard error == nil else {
          print("An error occured. Not showing data.")
          self.error = error
          return
        }

        // Show data view
        self.loading = !self.loading

      })
  }
  
}

struct ContentView_Previews: PreviewProvider {
  static var previews: some View {
    OFFetchReportsMainView()
  }
}
