//
//  CanvasTutorialStep.swift
//  FilmsPage
//
//  Defines each step in the interactive production canvas tutorial.
//

import Foundation

enum CanvasTutorialStep: Int, CaseIterable, Codable {
    case introduction        = 0
    case hierarchyPanel      = 1
    case closeHierarchy      = 2
    case compass             = 3
    case shotBreakdown       = 4
    case dismissBreakdown    = 5
    case panGesture          = 6
    case orbitGesture        = 7
    case zoomGesture         = 8
    case menuBar             = 9
    case addProp             = 10
    case rotateProp          = 11
    case addCharacter        = 12
    case addCamera           = 13
    case addLight            = 14
    case addBackground       = 15
    case addWall             = 16
    case addSky              = 17
    case selection           = 18
    case longPressMenu       = 19
    case entityEditing       = 20
    case sceneOrganization   = 21
    case completion          = 22
    case completed           = 100

    var title: String {
        switch self {
        case .introduction:      return "Canvas Walkthrough"
        case .hierarchyPanel:    return "Scene Hierarchy"
        case .closeHierarchy:    return "Close Hierarchy"
        case .compass:           return "Compass View"
        case .shotBreakdown:     return "Shot Breakdown"
        case .dismissBreakdown:  return "Return to Canvas"
        case .panGesture:        return "Pan Gesture"
        case .orbitGesture:      return "Orbit Gesture"
        case .zoomGesture:       return "Zoom Gesture"
        case .menuBar:           return "Asset Library"
        case .addProp:           return "Spawning Props"
        case .rotateProp:        return "Object Rotation"
        case .addCharacter:      return "Add Characters"
        case .addCamera:         return "Add Scene Camera"
        case .addLight:          return "Scene Lighting"
        case .addBackground:     return "Add Backgrounds"
        case .addWall:           return "Wall & Ground Editor"
        case .addSky:            return "Dynamic Sky"
        case .selection:         return "Object Selection"
        case .longPressMenu:     return "Context Actions"
        case .entityEditing:     return "Edit Actions"
        case .sceneOrganization: return "Workspace Organization"
        case .completion:        return "You're All Set!"
        case .completed:         return ""
        }
    }

    var message: String {
        switch self {
        case .introduction:
            return "Welcome to the Canvas! This is the scene visualization workspace where you bring your plans and sets to life."
        case .hierarchyPanel:
            return "Tap the layers icon to open the Scene Hierarchy panel and inspect all spawned entities."
        case .closeHierarchy:
            return "Here you see active items grouped by type. Now, tap the close 'X' button to return to the canvas."
        case .compass:
            return "This compass shows camera orientation and workspace center direction. You can also tap 'N' to snap North."
        case .shotBreakdown:
            return "Tap the Shot Breakdown director icon to edit camera movements, configure timing tracks, and plan scene clips."
        case .dismissBreakdown:
            return "Use the back arrow in the Shot Breakdown toolbar to exit the timeline editor and return to the 3D viewport."
        case .panGesture:
            return "Move the scene around by sliding two fingers on the canvas. Try it now to translate the camera."
        case .orbitGesture:
            return "Orbit the camera's view center by sliding with a single finger on empty space. Rotate the scene now."
        case .zoomGesture:
            return "Zoom the camera in or out by pinching two fingers together or apart. Perform a zoom now."
        case .menuBar:
            return "This top floating toolbar holds the catalogs for all 3D assets, cameras, lighting equipment, and sky presets."
        case .addProp:
            return "Tap the Prop icon (cube) in the toolbar, select an item, and spawn it on the canvas."
        case .rotateProp:
            return "Rotate the selected object. Touch and drag the blue/red outer gizmo rings or the bottom-right Rotate mode tool."
        case .addCharacter:
            return "Characters form the focal points of your shots. Tap the Character icon and place one on the set."
        case .addCamera:
            return "Add a scene camera. Once added, you can look through its view in the right-side camera previews."
        case .addLight:
            return "Add a dynamic light to set the scene's mood. Tap the bulb icon and place one now."
        case .addBackground:
            return "You can add backdrops to frame your horizon. Tap the image icon and spawn a background."
        case .addWall:
            return "Draw custom walls or ground segments to divide sets. Tap the grid icon and place one now."
        case .addSky:
            return "Change environmental lighting and colors instantly by tapping the sky cloud icon and selecting a preset."
        case .selection:
            return "Select any entity on the canvas by tapping it directly. Tap a spawned object now."
        case .longPressMenu:
            return "Open context controls by performing a long-press on the selected object on the canvas."
        case .entityEditing:
            return "Use context controls to Rename, Edit materials, Lock, or Duplicate. Tap 'Duplicate' or 'Rename' now."
        case .sceneOrganization:
            return "Spawning, scaling, and editing are fully tracked. Any changes instantly sync with the Scene Hierarchy list."
        case .completion:
            return "You now know the core workflow of the production canvas. Start building your scenes."
        case .completed:
            return ""
        }
    }

    var isInteractionRequired: Bool {
        switch self {
        case .introduction, .compass, .menuBar, .sceneOrganization, .completion, .completed:
            return false
        default:
            return true
        }
    }

    var hint: String? {
        switch self {
        case .hierarchyPanel:    return "Tap the layers icon to proceed"
        case .closeHierarchy:    return "Tap the 'X' button to proceed"
        case .shotBreakdown:     return "Tap the director icon to proceed"
        case .dismissBreakdown:  return "Return to the canvas"
        case .panGesture:        return "Perform a 2-finger pan gesture"
        case .orbitGesture:      return "Perform a 1-finger orbit gesture"
        case .zoomGesture:       return "Perform a pinch zoom gesture"
        case .addProp:           return "Spawn a prop to proceed"
        case .rotateProp:        return "Rotate the object using the gizmo rings"
        case .addCharacter:      return "Spawn a character to proceed"
        case .addCamera:         return "Spawn a camera to proceed"
        case .addLight:          return "Spawn a light to proceed"
        case .addBackground:     return "Spawn a background to proceed"
        case .addWall:           return "Spawn a wall or ground to proceed"
        case .addSky:            return "Change sky template to proceed"
        case .selection:         return "Tap an entity on the canvas"
        case .longPressMenu:     return "Long press the selected entity"
        case .entityEditing:     return "Select 'Duplicate' or 'Rename' in the menu"
        default:                 return nil
        }
    }

    var displayIndex: Int {
        switch self {
        case .introduction:      return 1
        case .hierarchyPanel:    return 2
        case .closeHierarchy:    return 3
        case .compass:           return 4
        case .shotBreakdown:     return 5
        case .dismissBreakdown:  return 6
        case .panGesture:        return 7
        case .orbitGesture:      return 8
        case .zoomGesture:       return 9
        case .menuBar:           return 10
        case .addProp:           return 11
        case .rotateProp:        return 12
        case .addCharacter:      return 13
        case .addCamera:         return 14
        case .addLight:          return 15
        case .addBackground:     return 16
        case .addWall:           return 17
        case .addSky:            return 18
        case .selection:         return 19
        case .longPressMenu:     return 20
        case .entityEditing:     return 21
        case .sceneOrganization: return 22
        case .completion:        return 23
        default:                 return 0
        }
    }

    static var totalDisplaySteps: Int {
        return 23
    }
}
