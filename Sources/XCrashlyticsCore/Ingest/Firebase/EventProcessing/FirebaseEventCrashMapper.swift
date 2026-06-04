//
//  FirebaseEventCrashMapper.swift
//  xcrashlytics
//
//  Created by FIRAT TAMUR on 8.06.2026.
//

import Foundation

public enum FirebaseEventCrashMapper {
    public static func crashRecord(
        from event: FirebaseDTO.EventDTO,
        canonicalId: String,
        frameOptions: FirebaseFrameFilterOptions = FirebaseFrameFilterOptions()
    ) -> CrashRecord {
        let frames = FirebaseEventFrames.frames(from: event, options: frameOptions)
        let timestamp = event.eventTime.flatMap(EventDates.parse)
        return CrashRecord(
            id: canonicalId,
            source: .firebase,
            bundleVersion: event.version?.displayVersion,
            osVersion: event.operatingSystem?.displayVersion,
            deviceModel: event.device?.model,
            crashedThreadIndex: 0,
            exception: ExceptionInfo(exceptionType: event.exceptions?.first?.type ?? "FIREBASE_EVENT"),
            frames: frames,
            timestamp: timestamp
        )
    }
}
