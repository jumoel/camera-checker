import ArgumentParser
//
//  main.swift
//  onair
//
// Created by wouter.de.bie on 11/17/19.
// Modified by Julian Møller Ellehauge 2024
// Copyright © 2019 evenflow. All rights reserved.
//
import Cocoa
import Foundation
import Logging
import TSCBasic
import TSCUtility

let logger = Logger(label: "com.jumoel.camera-checker")
LoggingSystem.bootstrap(StreamLogHandler.standardError)

// We run the actual CameraChecker in a sub process, since it will
// exit if it encounters added or removed USB devices. This is super
// crude, but it's a simple way of reinitializing all cams whenever
// something changes.
var child: Foundation.Process?

// Setup SIGINT and SIGTERM to terminate both the parent and child process.
signal(SIGINT, SIG_IGN)
signal(SIGTERM, SIG_IGN)

let sigintSrc = DispatchSource.makeSignalSource(signal: SIGINT, queue: .main)
let sigtermSrc = DispatchSource.makeSignalSource(signal: SIGTERM, queue: .main)

func die() {
	child?.terminate()
	exit(0)
}

sigintSrc.setEventHandler(handler: die)
sigintSrc.resume()

sigtermSrc.setEventHandler(handler: die)
sigtermSrc.resume()

struct OnAir: ParsableCommand {
	@Option(
		help: ArgumentHelp(
			"(optional) Comma-separated list of camera names to ignore", valueName: "list"))
	var ignore: String?

	@Flag(help: ArgumentHelp("Show extra debug information"))
	var debug = false

	mutating func run() throws {
		var childArgs: [String] = []

		if ignore != nil {
			childArgs += ["--ignore", ignore!]
		}

		if debug {
			childArgs += ["--debug"]
		}

		let processInfo = ProcessInfo.processInfo
		var environment = processInfo.environment

		if environment["CAMERACHECKER_SPECIAL_VAR"] != nil {
			if debug {
				logger.info("Debug in child: \(debug)")
			}
			CameraChecker(
				ignore: ignore,
				debug: debug
			).checkCameras()
			RunLoop.main.run()
		} else {
			// We're in the parent.
			while true {
				environment["CAMERACHECKER_SPECIAL_VAR"] = "1"

				child = Process()
				child!.launchPath = processInfo.arguments[0]
				child!.environment = environment
				child!.arguments = childArgs
				child!.launch()
				child!.waitUntilExit()
			}
		}
	}
}

OnAir.main()
