import Foundation

struct LightItem {
    let name: String
    let imageName: String
    let description: String
    var modelFileName: String? = nil
}

struct LightsDataStore {


    private(set) static var items: [LightItem] = [
        LightItem(
            name: "LED Panel",
            imageName: "LED Panel_img",        
            description: "Soft, even light source ideal for key or fill.",
            modelFileName: "LED Panel"
        ),
        LightItem(
            name: "Lantern",
            imageName: "Lantern_img",
            description: "Soft omnidirectional light often used as a hanging practical.",
            modelFileName: "Lantern 2"
        ),
        LightItem(
            name: "Spotlight",
            imageName: "Spotlight_img 1",
            description: "Narrow beam for highlighting specific areas or subjects.",
            modelFileName: "Spotlight"
        )
    ]

    // Optional: add new lights later
    static func addLight(name: String, imageName: String, description: String) {
        let newLight = LightItem(name: name, imageName: imageName, description: description)
        items.append(newLight)
    }
}
