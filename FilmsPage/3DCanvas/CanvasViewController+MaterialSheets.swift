//
//  CanvasViewController+MaterialSheets.swift
//  FilmsPage
//
//  Extension providing sheet presentation helpers for the cinematic
//  material workflow: wall creation, ground creation, and material editing.
//

import UIKit
import SwiftUI
import RealityKit

extension CanvasViewController {

    // MARK: - Wall Creation Sheet

    func presentWallCreationSheet() {
        let viewModel = WallCreationViewModel()

        viewModel.onConfirm = { [weak self] width, height, thickness, config in
            guard let self = self else { return }
            self.dismiss(animated: true) {
                if let entity = self.spawnCinematicWall(
                    width: width,
                    height: height,
                    thickness: thickness,
                    materialConfig: config
                ) {
                    self.selectedEntity = entity
                    self.refreshSidebarContent()
                }
            }
        }

        viewModel.onCancel = { [weak self] in
            self?.dismiss(animated: true)
        }

        let wallView = WallCreationView(viewModel: viewModel)
        let hostingController = UIHostingController(rootView: wallView)
        hostingController.modalPresentationStyle = .pageSheet

        if let sheet = hostingController.sheetPresentationController {
            sheet.detents = [.large()]
            sheet.prefersGrabberVisible = true
            sheet.preferredCornerRadius = 20
        }

        present(hostingController, animated: true)
    }

    // MARK: - Ground Creation Sheet

    func presentGroundCreationSheet() {
        let viewModel = GroundCreationViewModel()

        viewModel.onConfirm = { [weak self] size, config in
            guard let self = self else { return }
            self.dismiss(animated: true) {
                if let entity = self.spawnCinematicGround(
                    size: size,
                    materialConfig: config
                ) {
                    self.selectedEntity = entity
                    self.refreshSidebarContent()
                }
            }
        }

        viewModel.onCancel = { [weak self] in
            self?.dismiss(animated: true)
        }

        let groundView = GroundCreationView(viewModel: viewModel)
        let hostingController = UIHostingController(rootView: groundView)
        hostingController.modalPresentationStyle = .pageSheet

        if let sheet = hostingController.sheetPresentationController {
            sheet.detents = [.large()]
            sheet.prefersGrabberVisible = true
            sheet.preferredCornerRadius = 20
        }

        present(hostingController, animated: true)
    }

    // MARK: - Material Editor Sheet
    func presentMaterialEditor(for entity: ModelEntity) {
        let viewModel = MaterialEditorViewModel()
        let isWall = entity.components[WallComponent.self] != nil
        viewModel.configure(entity: entity, isWall: isWall)

        viewModel.onDismiss = { [weak self] in
            self?.dismiss(animated: true)
        }

        let editorView = MaterialEditorView(
            viewModel: viewModel,
            entity: entity,
            isWall: isWall
        )
        let hostingController = UIHostingController(rootView: editorView)
        hostingController.modalPresentationStyle = .pageSheet

        if let sheet = hostingController.sheetPresentationController {
            sheet.detents = [.medium(), .large()]
            sheet.prefersGrabberVisible = true
            sheet.preferredCornerRadius = 20
        }

        present(hostingController, animated: true)
    }
}
