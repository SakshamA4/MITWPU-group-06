import Foundation

struct LightItem {
    let name: String
    let imageName: String
    let description: String
}

struct LightsDataStore {

    // 🔹 This is what your view controller is trying to read: LightsDataStore.items
    private(set) static var items: [LightItem] = [
        LightItem(
            name: "LED Panel",
            imageName: "Image",        // change to your asset name
            description: "Soft, even light source ideal for key or fill."
        ),
        LightItem(
            name: "Practical Lantern",
            imageName: "Image",
            description: "Visible lantern in frame used as both source and prop."
        ),
        LightItem(
            name: "Practical Spotlight",
            imageName: "Image",
            description: "Focused practical light creating a strong beam or pool."
        ),
        LightItem(
            name: "Ring Light",
            imageName: "Image",
            description: "Circular light giving an even, flattering glow and eye ring."
        ),
        LightItem(
            name: "Fluorescent Tube",
            imageName: "Image",
            description: "Long tube light, good for industrial or stylised looks."
        ),
        LightItem(
            name: "Lantern",
            imageName: "Image",
            description: "Soft omnidirectional light often used as a hanging practical."
        ),
        LightItem(
            name: "Spotlight",
            imageName: "Image",
            description: "Narrow beam for highlighting specific areas or subjects."
        ),
        LightItem(
            name: "Flood Light",
            imageName: "Image",
            description: "Wide, powerful light used to wash large areas."
        ),
        LightItem(
            name: "Fluorescent Tube 2",
            imageName: "Image",
            description: "Second variation of fluorescent tube for a different look/colour."
        ),
        LightItem(
            name: "Fluorescent Tube 3",
            imageName: "Image",
            description: "Third variation of fluorescent tube for extra flexibility."
        )
    ]

    // Optional: add new lights later
    static func addLight(name: String, imageName: String, description: String) {
        let newLight = LightItem(name: name, imageName: imageName, description: description)
        items.append(newLight)
    }
}
