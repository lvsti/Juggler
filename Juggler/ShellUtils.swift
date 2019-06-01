//
//  ShellUtils.swift
//  Juggler
//
//  Created by Tamas Lustyik on 2019. 06. 01..
//  Copyright © 2019. Tamas Lustyik. All rights reserved.
//

import Foundation

enum ShellError: Error {
    case unknown
}

@discardableResult
func shell(_ command: String, args: [String], verbose: Bool = false) throws -> String {
    let ps = Process()
    ps.launchPath = command
    ps.arguments = args
    
    let outputPipe = Pipe()
    let errorPipe = Pipe()
    ps.standardOutput = outputPipe
    ps.standardError = errorPipe
    
    ps.launch()
    
    var outputPipeResult = Data()
    var errorPipeResult = Data()
    
    while ps.isRunning {
        outputPipeResult.append(outputPipe.fileHandleForReading.readDataToEndOfFile())
        errorPipeResult.append(errorPipe.fileHandleForReading.readDataToEndOfFile())
    }
    
    guard
        let output = String(data: outputPipeResult, encoding: String.Encoding.utf8),
        let error = String(data: errorPipeResult, encoding: String.Encoding.utf8)
    else {
        printError("\(command) \(args.joined(separator: " "))")
        printError("Error parsing the output of the previous command.")
        throw ShellError.unknown
    }
    
    guard ps.terminationStatus == 0 else {
        printError("\(command) \(args.joined(separator: " "))")
        printError("Terminated with status \(ps.terminationStatus).")
        printError(output)
        printError(error)
        throw ShellError.unknown
    }
    
    if verbose {
        print("\(command) \(args.joined(separator: " "))")
        print(output)
        printError(error)
    }
    
    return output
}

func printError(_ msg: String) {
    msg.withCString { cstr in
        fputs(cstr, stderr)
        fputs("\n", stderr)
    }
}
