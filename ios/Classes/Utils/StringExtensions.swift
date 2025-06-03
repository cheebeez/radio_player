/*
 * StringExtensions.swift
 *
 * Copyright (c) 2020-2025 Ilia Chirkunov <contact@cheebeez.com>
 * (Or your copyright if these are your extensions)
 *
 * This source code is licensed under the CC BY-NC-SA 4.0.
 * See https://creativecommons.org/licenses/by-nc-sa/4.0/
 */

import Foundation

extension Optional where Wrapped == String {
    /// Returns `nil` if `nil`, otherwise calls `nilIfEmpty()` on the unwrapped string.
    func nilIfEmpty() -> String? {
        return self?.nilIfEmpty()
    }
}

extension String {
    /// Returns `nil` if empty or whitespace after trimming, else returns the trimmed string.
    func nilIfEmpty() -> String? {
        let trimmed = self.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
