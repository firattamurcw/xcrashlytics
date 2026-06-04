//
//  CommandSurfaceTests.swift
//  xcrashlyticsTests
//
//  Created by FIRAT TAMUR on 8.06.2026.
//

import Testing
@testable import xcrashlytics

@Suite("xcrashlytics command surface")
struct CommandSurfaceTests {
    @Test("dsyms command is not registered")
    func dsymsCommandIsNotRegistered() {
        let subcommands = XcrashlyticsCommand.configuration.subcommands.map { String(describing: $0) }

        #expect(!subcommands.contains("DSYMsCommand"))
    }

    @Test("watch command is not registered")
    func watchCommandIsNotRegistered() {
        let subcommands = XcrashlyticsCommand.configuration.subcommands.map { String(describing: $0) }

        #expect(!subcommands.contains("WatchCommand"))
    }
}
