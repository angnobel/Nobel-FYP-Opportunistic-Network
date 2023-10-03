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
  @State var keyPlistFile: Data?

  @State var showModemPrompt = false
  @State var repeatTime: Int = 0
  @State var numMessages: Int = 1
  
  @State var isRepeatingFetch: Bool = true
  
  @State private var timer: Timer?

  var modemIDView: some View {
      VStack {
          Spacer()
          Text("Please insert the modem id that you want to fetch data for:")
          HStack {
              Spacer()
              TextField("4 byte hex string, e.g. DE AD BE EF", text: self.$modemIDString).frame(width: 250)

              Text("Repeat Time (s):")
              TextField("Enter Repeat Time", value: self.$repeatTime, formatter: NumberFormatter()).frame(width: 100)
          
              Text("Number of Messages:")
              TextField("Enter Number of Messages", value: self.$numMessages, formatter: NumberFormatter()).frame(width: 100)
                
              Button(
                  action: {
                      guard let parsedModemID = UInt32(self.modemIDString.replacingOccurrences(of: " ", with: "", options: NSString.CompareOptions.literal, range: nil), radix: 16) else { return }
                      
                      self.modemID = parsedModemID
                      self.isRepeatingFetch = true
                      print("Parsed Modem ID: \(parsedModemID); " + String(parsedModemID, radix: 16))
                      print("Time to repeat search, in seconds: " + String(repeatTime))
                      print("Number of messages to automatically fetch: " + String(numMessages))
                      self.findMyController.clearMessages()
                    
                      loadMultiMessage(modemID:parsedModemID, numMessages: numMessages)
                      isRepeatingFetch = repeatTime > 0
                      
                      
                  },
                  label: {
                      Text("Download data")
                  })
              Spacer()
          }
          Spacer()
          
          // Add input fields for repeat time and numMessages
          
          Spacer()
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
           ForEach(0...max(10, self.findMyController.messages.count+1), id: \.self) { i in
            if  self.findMyController.messages[UInt32(i)] != nil {
             HStack {
              Text("#\(self.findMyController.messages[UInt32(i)]!.messageID)").font(.system(size: 14, design: .monospaced)).frame(width: 30)
              Text(self.findMyController.messages[UInt32(i)]!.decodedStr ?? "<None>").font(.system(size: 14, design: .monospaced))
        
              Spacer()
                  Button(
                    action: {
                        self.loadMessage(modemID: self.modemID, messageID: self.findMyController.messages[UInt32(i)]!.messageID)
                    },
                    label: {
                      Text("Reload message")
                    })
                 }
            } else {
                
               Button(
                    action: {
                        self.loadMessage(modemID: self.modemID, messageID: UInt32(i))
                    },
                    label: {
                      Text("Load message #\(i)")
                    })
               //Spacer()
               
            
           }
        } 
     }.onAppear {
       // Start the timer when the view appears
       if self.isRepeatingFetch && self.repeatTime > 0 {
           // Convert repeatTime to TimeInterval
           let repeatTimeInterval: TimeInterval = TimeInterval(self.repeatTime)
           
           // Start the timer
           self.timer = Timer.scheduledTimer(withTimeInterval: repeatTimeInterval, repeats: true) { _ in
               // Call your function when the timer fires
               self.loadMultiMessage(modemID: self.modemID, numMessages: self.numMessages)
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
        self.loadingView
      } else if self.showData {
        self.dataView
      } else if self.showModemPrompt {
        self.modemIDView
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
        
            AnisetteDataManager.shared.requestAnisetteData { result in
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
                self.downloadAndDecodeData(modemID: modemID, messageID: UInt32(0), searchPartyToken: token)

            }
        }
    return true
  }
  
  func loadMultiMessage(modemID: UInt32, numMessages: Int) {
    // TODO: Make this run parellel
    for i in 0...numMessages-1 {
      self.loadMessage(modemID: modemID, messageID: UInt32(i))
    }
  }

  // swiftlint:disable identifier_name
  func loadMessage(modemID: UInt32, messageID: UInt32) -> Bool {
        self.messageIDToFetch = messageID
        print("Retrieving data")
        print(modemID)
        print(messageID)
        
            AnisetteDataManager.shared.requestAnisetteData { result in
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
                self.downloadAndDecodeData(modemID: modemID, messageID: messageID, searchPartyToken: token)
              

            }
        }
    return true
  }

  func downloadAndDecodeData(modemID: UInt32, messageID: UInt32, searchPartyToken: Data) {
    self.loading = true

    self.findMyController.fetchMessage(
      for: modemID, message: messageID, with: searchPartyToken,
      completion: { error in
        // Check if an error occurred
        guard error == nil else {
          print("An error occured. Not showing data.")
          self.error = error
          return
        }
        
        // Log packet time
        let currentTimestamp = Int(Date().timeIntervalSince1970)
        print("Current Unix Timestamp: \(currentTimestamp)")
        // Show data view
        self.loading = false
        self.showData = true

      })
  }
}

struct ContentView_Previews: PreviewProvider {
  static var previews: some View {
    OFFetchReportsMainView()
  }
}
