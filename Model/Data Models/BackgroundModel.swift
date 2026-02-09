//
//  BackgroundItem.swift
//  FilmsPage
//
//  Created by SDC-USER on 08/12/25.
//
import Foundation

struct BackgroundItem: Identifiable, Hashable {
    let id: UUID = UUID()
    var title: String
    var imageName: String
}
