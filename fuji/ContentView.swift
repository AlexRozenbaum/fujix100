import SwiftUI
import AppKit

extension String {
    func matchingString(usingRegex pattern: String) -> String? {
        do {
            let regex = try NSRegularExpression(pattern: pattern, options: [])
            if let match = regex.firstMatch(in: self, options: [], range: NSRange(location: 0, length: count)) {
                return (self as NSString).substring(with: match.range)
            }
        } catch {
            print("Regex error: \(error)")
        }
        return nil
    }
}

struct ContentView: View {
    @State private var selectedURLs: [URL] = []
    @State private var rafFiles: [RAFFile] = []
    @State private var scanMessage: String = ""
    @State private var selectedOptionIndex: Int = 0  // Add this line for selectedOptionIndex
        let predefinedOptions: [String] = [  // Add this array with predefined options
            "0201FF129504X100F \0X100F\0 X100F Ver2.11",
            "0201FF159504X100V \0X100V\0 X100V Ver1.00",
            "0201FF159505X-T4\0 \0X-T4\0\0 X-T4 Ver1.01\0",
        ]
    var body: some View {
            VStack {
                Button("Attach Files or Directories and Then Scan for RAF Files") {
                    openAttachmentPanel()
                }
                Picker("Select Option For Change", selection: $selectedOptionIndex) {
                                ForEach(0..<predefinedOptions.count, id: \.self) { index in
                                    Text(predefinedOptions[index]).tag(index)
                                }
                            }
                            .pickerStyle(MenuPickerStyle())
                            .frame(maxWidth: 500)

                            Button("Write Selected Option to All Files") {
                                writeSelectedOptionToAllFiles()
                            }
                
                if !selectedURLs.isEmpty {
                    Text("Selected URLs:")
                    ScrollView {
                                           ForEach(selectedURLs, id: \.self) { url in
                                               Text(url.path)
                                           }
                                       }
                    
                    Button("Scan for  FUJI x100seria RAF Files or Alreary converted X-T4 RAF Files") {
                        scanForRAFFiles()
                    }
                    
                    if !rafFiles.isEmpty {
                        List {
                            ForEach($rafFiles) { $rafFile in
                                RAFFileView(rafFile: $rafFile)
                            }
                        }
                    } else {
                        Text(scanMessage)
                    }
                }
            }
            .onAppear {
                // Refresh the RAF files when the view appears
                scanForRAFFiles()
            }
        }
    

    private func openAttachmentPanel() {
            let openPanel = NSOpenPanel()
            openPanel.canChooseFiles = true
            openPanel.canChooseDirectories = true
            openPanel.allowsMultipleSelection = true
            openPanel.begin { response in
                if response == .OK {
                    selectedURLs = openPanel.urls
                    rafFiles.removeAll()
                    scanMessage = ""
                }
            }
        }
    

    private func writeSelectedOptionToAllFiles() {
        guard selectedOptionIndex < predefinedOptions.count else {
            return
        }

        let selectedOption = predefinedOptions[selectedOptionIndex]
        let parts = selectedOption.components(separatedBy: " ")

        guard parts.count >= 3 else {
            print("Invalid selected option format.")
            return
        }

        let newSerialNumber = parts[0]
        let newModel = parts[1]
        let newFirmwareVersion = parts[2...]

        for index in rafFiles.indices {
            do {
                let url = rafFiles[index].url
                guard var data = try? Data(contentsOf: url) else {
                    print("Error reading file data.")
                    continue // Skip to the next file if data cannot be read
                }
                
                // Convert the first 500 bytes into ASCII text
                guard let asciiText = String(data: data.prefix(500), encoding: .ascii) else {
                    print("Error converting data to ASCII text.")
                    continue // Skip to the next file if conversion fails
                }

                let startIndex = asciiText.startIndex

                // Calculate character offsets
                let serialNumberStartIndexStringOffset = asciiText.distance(from: startIndex, to: rafFiles[index].serialNumberRange.lowerBound)
                let serialNumberEndIndexStringOffset = asciiText.distance(from: startIndex, to: rafFiles[index].serialNumberRange.upperBound)

                let modelStartIndexStringOffset = asciiText.distance(from: startIndex, to: rafFiles[index].modelRange.lowerBound)
                let modelEndIndexStringOffset = asciiText.distance(from: startIndex, to: rafFiles[index].modelRange.upperBound)

                let firmwareVersionStartIndexStringOffset = asciiText.distance(from: startIndex, to: rafFiles[index].firmwareVersionRange.lowerBound)
                let firmwareVersionEndIndexStringOffset = asciiText.distance(from: startIndex, to: rafFiles[index].firmwareVersionRange.upperBound)

                // Create ranges using the character offsets
                let serialNumberRangeConverted = serialNumberStartIndexStringOffset..<serialNumberEndIndexStringOffset
                let modelRangeConverted = modelStartIndexStringOffset..<modelEndIndexStringOffset
                let firmwareVersionRangeConverted = firmwareVersionStartIndexStringOffset..<firmwareVersionEndIndexStringOffset

                // Use the ranges as needed
                print("Serial Number Range: \(serialNumberRangeConverted)")
                print("Model Range: \(modelRangeConverted)")
                print("Firmware Version Range: \(firmwareVersionRangeConverted)")

                if let newSerialNumberConverted = newSerialNumber.data(using: .utf8),
                   let newModelConverted = newModel.data(using: .utf8),
                   let newMFirmwareVersionConverted = newFirmwareVersion.joined(separator: " ").data(using: .utf8) {
                    
                    print(newSerialNumberConverted, newModelConverted, newMFirmwareVersionConverted)
                    data.replaceSubrange(serialNumberRangeConverted, with: newSerialNumberConverted)
                    data.replaceSubrange(modelRangeConverted, with: newModelConverted)
                    data.replaceSubrange(firmwareVersionRangeConverted, with: newMFirmwareVersionConverted)

                    do {
                        try data.write(to: url, options: .atomic)
                        print("Modifications written to the same file:", url.path)
                        rafFiles[index].serialNumber = newSerialNumber
                        rafFiles[index].model = newModel
                        rafFiles[index].firmwareVersion = newFirmwareVersion.joined(separator: " ")
                        print(rafFiles[index].model.count)
                    } catch {
                        print("Error writing selected option for index \(index): \(error)")
                    }
                } else {
                    print("Error converting char data to Data.")
                }
            } catch {
                print("Error reading file data for index \(index): \(error)")
            }
        }
    }


    private func scanForRAFFiles() {
        // Clear the existing list of RAF files before scanning
        rafFiles.removeAll()

        for url in selectedURLs {
            if url.isFileURL && url.pathExtension.lowercased() == "raf" {
                print("Processing RAF file:", url.path)

                do {
                    let data = try Data(contentsOf: url)
                    let first500Bytes = data.prefix(500) // Get the first 500 bytes of data

                    // Convert binary data to ASCII text
                    if let asciiText = String(data: first500Bytes, encoding: .ascii) {
                        // Print the ASCII text for debugging
                        print("ASCII Text:", asciiText)
                        

                        // Define the regular expression patterns
                        let serialNumberPattern = "(\\d{4}FF\\d{6})(X100[STFV]|X-T[45]\0)"
                        let modelPattern = "(\0X100[STFV]\0)|(\0X-T[45]\0\0)"
                        let firmwarePattern =  "(X100[STFV] Ver\\d\\.\\d\\d)|(X-T[45] Ver\\d\\.\\d\\d\0)"
                       
                        if let serialNumber = asciiText.matchingString(usingRegex: serialNumberPattern),
                           let model = asciiText.matchingString(usingRegex: modelPattern),
                           let firmwareVersion = asciiText.matchingString(usingRegex: firmwarePattern)
                        {


                            let serialNumberRange = asciiText.range(of: serialNumber)!
                            let modelRange = asciiText.range(of: model)!
                            let firmwareVersionRange = asciiText.range(of: firmwareVersion)!
                            
                            let serialNumberRangeInData = serialNumberRange.lowerBound..<serialNumberRange.upperBound
                            let modelRangeInData = modelRange.lowerBound..<modelRange.upperBound
                            let firmwareVersionRangeInData = firmwareVersionRange.lowerBound..<firmwareVersionRange.upperBound
                            print("Serial Number Range:", serialNumberRange.lowerBound)
                            print("Model Range:", modelRange.lowerBound)
                            print("Firmware Version Range:", firmwareVersionRange.lowerBound)
                            let serialNumberStart = serialNumberRange.lowerBound.utf16Offset(in: asciiText)
                            let serialNumberEnd = serialNumberRange.upperBound.utf16Offset(in: asciiText)
                            print("Serial Number Range Start: \(serialNumberStart), End: \(serialNumberEnd)")

                            let modelStart = modelRange.lowerBound.utf16Offset(in: asciiText)
                            let modelEnd = modelRange.upperBound.utf16Offset(in: asciiText)
                            print("Model Range Start: \(modelStart), End: \(modelEnd)")

                            let firmwareVersionStart = firmwareVersionRange.lowerBound.utf16Offset(in: asciiText)
                            let firmwareVersionEnd = firmwareVersionRange.upperBound.utf16Offset(in: asciiText)
                            print("Firmware Version Range Start: \(firmwareVersionStart), End: \(firmwareVersionEnd)")
                            let modelWithoutNulls = model.replacingOccurrences(of: "\0", with: "")
                            print(modelWithoutNulls,modelWithoutNulls.count)
                            rafFiles.append(RAFFile(url: url, isSelected: false, serialNumber: serialNumber, model: modelWithoutNulls, firmwareVersion: firmwareVersion, serialNumberRange: serialNumberRangeInData, modelRange: modelRangeInData, firmwareVersionRange: firmwareVersionRangeInData))
                            
                        } else {
                            print("Patterns not found in data:", url.path)
                        }
                    } else {
                        print("Error converting binary data to ASCII text.")
                    }
                } catch {
                    print("Error reading file: \(error)")
                }
            } else if url.hasDirectoryPath {
                // Scan the directory for RAF files
                scanDirectoryForRAFFiles(directoryURL: url)
            }
        }

        if rafFiles.isEmpty {
            scanMessage = "No RAF files found."
        } else {
            scanMessage = ""
        }
    }
    private func scanDirectoryForRAFFiles(directoryURL: URL) {
        // Clear the existing list of RAF files before scanning
        rafFiles.removeAll()
        do {
            let directoryContents = try FileManager.default.contentsOfDirectory(at: directoryURL, includingPropertiesForKeys: nil, options: [])
            
            for url in directoryContents {
                if url.pathExtension.lowercased() == "raf" {
                    // Move the do-catch block here
                    do {
                        let data = try Data(contentsOf: url)
                        let first500Bytes = data.prefix(500) // Get the first 500 bytes of data
                        
                        // Convert binary data to ASCII text
                        if let asciiText = String(data: first500Bytes, encoding: .ascii) {
                            // Print the ASCII text for debugging
                            print("ASCII Text:", asciiText)
                            
                            // Define the regular expression patterns
                            let serialNumberPattern = "(\\d{4}FF\\d{6})(X100[STFV]|X-T[45]\0)"
                            let modelPattern = "(\0X100[STFV]\0)|(\0X-T[45]\0\0)"
                            let firmwarePattern = "(X100[STFV] Ver\\d\\.\\d\\d)|(X-T[45] Ver\\d\\.\\d\\d\0)"
                            
                            if let serialNumber = asciiText.matchingString(usingRegex: serialNumberPattern),
                               let model = asciiText.matchingString(usingRegex: modelPattern),
                               let firmwareVersion = asciiText.matchingString(usingRegex: firmwarePattern) {
                                
                                let serialNumberRange = asciiText.range(of: serialNumber)!
                                let modelRange = asciiText.range(of: model)!
                                let firmwareVersionRange = asciiText.range(of: firmwareVersion)!
                                
                                let serialNumberRangeInData = serialNumberRange.lowerBound..<serialNumberRange.upperBound
                                let modelRangeInData = modelRange.lowerBound..<modelRange.upperBound
                                let firmwareVersionRangeInData = firmwareVersionRange.lowerBound..<firmwareVersionRange.upperBound
                                print("Serial Number Range:", serialNumberRange.lowerBound)
                                print("Model Range:", modelRange.lowerBound)
                                print("Firmware Version Range:", firmwareVersionRange.lowerBound)
                                let serialNumberStart = serialNumberRange.lowerBound.utf16Offset(in: asciiText)
                                let serialNumberEnd = serialNumberRange.upperBound.utf16Offset(in: asciiText)
                                print("Serial Number Range Start: \(serialNumberStart), End: \(serialNumberEnd)")
                                
                                let modelStart = modelRange.lowerBound.utf16Offset(in: asciiText)
                                let modelEnd = modelRange.upperBound.utf16Offset(in: asciiText)
                                print("Model Range Start: \(modelStart), End: \(modelEnd)")
                                
                                let firmwareVersionStart = firmwareVersionRange.lowerBound.utf16Offset(in: asciiText)
                                let firmwareVersionEnd = firmwareVersionRange.upperBound.utf16Offset(in: asciiText)
                                print("Firmware Version Range Start: \(firmwareVersionStart), End: \(firmwareVersionEnd)")
                                
                                let modelWithoutNulls = model.replacingOccurrences(of: "\0", with: "")
                                print(modelWithoutNulls, modelWithoutNulls.count)
                                
                                rafFiles.append(RAFFile(url: url, isSelected: false, serialNumber: serialNumber, model: modelWithoutNulls, firmwareVersion: firmwareVersion, serialNumberRange: serialNumberRangeInData, modelRange: modelRangeInData, firmwareVersionRange: firmwareVersionRangeInData))
                            } else {
                                print("Patterns not found in data:", url.path)
                            }
                        } else {
                            print("Error converting binary data to ASCII text.")
                        }
                    } catch {
                        print("Error reading file: \(error)")
                    }
                }
            }
            
            if rafFiles.isEmpty {
                scanMessage = "No RAF files found."
            } else {
                scanMessage = ""
            }
        } catch {
            print("Error reading directory: \(error)")
        }
    }


    

    private func readCharData(from data: Data, range: Range<Int>) -> String {
        // Check if the range is within the bounds of the data
        guard range.lowerBound >= 0, range.upperBound <= data.count else {
            return "" // Return an empty string or handle the error as needed
        }
        
        let subdata = data.subdata(in: range)
        return String(data: subdata, encoding: .utf8) ?? ""
    }

}

struct RAFFileView: View {
    @Binding var rafFile: RAFFile
    @State private var selectedOptionIndex: Int = 0
    
    
    let predefinedOptions: [(String)] = [
        ("0201FF129504X100F \0X100F\0 X100F Ver2.11"),
        ("0201FF159504X100V \0X100V\0 X100V Ver1.00"),
        ("0201FF159505X-T4\0 \0X-T4\0\0 X-T4 Ver1.01\0"),
        
    ]
    
    var body: some View {
        
        HStack {
            Text(rafFile.url.lastPathComponent)
            Picker("Select Option", selection: $selectedOptionIndex) {
                ForEach(0..<predefinedOptions.count, id: \.self) { index in
                    Text(predefinedOptions[index]).tag(index)
                }
            }
            .pickerStyle(MenuPickerStyle())
            .frame(maxWidth: 300)
            
            Button("Change") {
                writeSelectedOption()
            }
        }
        
        Text("Serial Number: \(rafFile.serialNumber)")
        Text("Model: \(rafFile.modelWithoutNulls)")
        Text("Firmware Version: \(rafFile.firmwareVersion)")
    }
    private func writeSelectedOption() {
        guard selectedOptionIndex < predefinedOptions.count else {
            return
        }

        let selectedOption = predefinedOptions[selectedOptionIndex]
        let parts = selectedOption.components(separatedBy: " ")

        guard parts.count >= 3 else {
            print("Invalid selected option format.")
            return
        }

        let newSerialNumber = parts[0]
        let newModel = parts[1]
        let newFirmwareVersion = parts[2...].joined(separator: " ")
    
        
        // Get the first 500 bytes of RAF file data

        guard var data = try? Data(contentsOf: rafFile.url) else {
            print("Error reading file data.")
            return
        }

        // Convert the first 500 bytes into ASCII text
        guard let asciiText = String(data: data, encoding: .ascii) else {
            print("Error converting data to ASCII text.")
            return
        }
        
        let startIndex = asciiText.startIndex

        // Calculate character offsets
        let serialNumberStartIndexStringOffset = asciiText.distance(from: startIndex, to: rafFile.serialNumberRange.lowerBound)
        let serialNumberEndIndexStringOffset = asciiText.distance(from: startIndex, to: rafFile.serialNumberRange.upperBound)
        
        let modelStartIndexStringOffset = asciiText.distance(from: startIndex, to: rafFile.modelRange.lowerBound)
        let modelEndIndexStringOffset = asciiText.distance(from: startIndex, to: rafFile.modelRange.upperBound)
        
        let firmwareVersionStartIndexStringOffset = asciiText.distance(from: startIndex, to: rafFile.firmwareVersionRange.lowerBound)
        let firmwareVersionEndIndexStringOffset = asciiText.distance(from: startIndex, to: rafFile.firmwareVersionRange.upperBound)

        // Create ranges using the character offsets
        let serialNumberRangeConverted = serialNumberStartIndexStringOffset..<serialNumberEndIndexStringOffset
        let modelRangeConverted = modelStartIndexStringOffset..<modelEndIndexStringOffset
        let firmwareVersionRangeConverted = firmwareVersionStartIndexStringOffset..<firmwareVersionEndIndexStringOffset

        // Use the ranges as needed
        print("Serial Number Range: \(serialNumberRangeConverted)")
        print("Model Range: \(modelRangeConverted)")
        print("Firmware Version Range: \(firmwareVersionRangeConverted)")

        if let newSerialNumberConverted = newSerialNumber.data(using: .utf8),
           let newModelConverted = newModel.data(using: .utf8),
           let newMFirmwareVersionConverted = newFirmwareVersion.data(using: .utf8) {
            
            print( newSerialNumberConverted,newModelConverted,newMFirmwareVersionConverted)
            data.replaceSubrange(serialNumberRangeConverted, with: newSerialNumberConverted)
            data.replaceSubrange(modelRangeConverted, with: newModelConverted)
            data.replaceSubrange(firmwareVersionRangeConverted, with: newMFirmwareVersionConverted)

            do {
                try data.write(to: rafFile.url, options: .atomic)
                print("Modifications written to the same file:", rafFile.url.path)
                rafFile.serialNumber = newSerialNumber
                rafFile.model = newModel
                rafFile.firmwareVersion = newFirmwareVersion
                print(rafFile.model.count)
            } catch {
                print("Error writing selected option: \(error)")
            }
        } else {
            print("Error converting char data to Data.")
        }
    }

}

struct RAFFile: Identifiable, Equatable {
    let id = UUID()
    let url: URL
    var isSelected: Bool
    var serialNumber: String
    var model: String
    var firmwareVersion: String
    var modelWithoutNulls: String {
        return model.replacingOccurrences(of: "\0", with: "")
    }
        
    var serialNumberRange: Range<String.Index>
    var modelRange: Range<String.Index>
    var firmwareVersionRange: Range<String.Index>
}

