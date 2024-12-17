import SwiftUI

@main
struct WallpapeApp: App {
    @StateObject private var wallpaperManager = WallpaperManager()
    
    var body: some Scene {
        MenuBarExtra("Wallpape", systemImage: "photo.on.rectangle") {
            Button("Ordner auswählen") {
                wallpaperManager.selectFolder()
            }
            .keyboardShortcut("o")
            
            Button("Hintergrundbild wechseln") {
                wallpaperManager.changeWallpaper()
            }
            .keyboardShortcut("w")
            .disabled(wallpaperManager.selectedFolder == nil)
            
            Divider()
            
            // Custom Images Section
            ForEach(wallpaperManager.customImages, id: \.name) { image in
                Button(image.name) {
                    wallpaperManager.setCustomWallpaper(image.url)
                }
            }
            
            Button("+ Eigenes Bild hinzufügen") {
                wallpaperManager.addCustomImage()
            }
            .disabled(wallpaperManager.customImages.count >= 3)
            
            Divider()
            
            Button("Weiß") {
                wallpaperManager.setColorWallpaper("white")
            }
            
            Button("Grau") {
                wallpaperManager.setColorWallpaper("gray")
            }
            
            Button("Schwarz") {
                wallpaperManager.setColorWallpaper("black")
            }
            
            Divider()
            
            Button("Beenden") {
                NSApplication.shared.terminate(nil)
            }
            .keyboardShortcut("q")
        }
    }
}

struct CustomImage: Codable {
    let name: String
    let url: URL
}

class WallpaperManager: ObservableObject {
    @Published var selectedFolder: URL?
    @Published var customImages: [CustomImage] = []
    
    init() {
        loadCustomImages()
    }
    
    private func loadCustomImages() {
        if let data = UserDefaults.standard.data(forKey: "customImages"),
           let decoded = try? JSONDecoder().decode([CustomImage].self, from: data) {
            customImages = decoded
        }
    }
    
    private func saveCustomImages() {
        if let encoded = try? JSONEncoder().encode(customImages) {
            UserDefaults.standard.set(encoded, forKey: "customImages")
        }
    }
    
    func addCustomImage() {
        guard customImages.count < 3 else { return }
        
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.jpeg, .png, .heic]
        panel.allowsMultipleSelection = false
        
        if panel.runModal() == .OK, let url = panel.url {
            // Kopiere das Bild in den App-Support-Ordner
            if let appSupportURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first {
                let appFolder = appSupportURL.appendingPathComponent("Wallpape")
                
                do {
                    // Erstelle den Ordner falls er nicht existiert
                    try FileManager.default.createDirectory(at: appFolder, withIntermediateDirectories: true)
                    
                    // Generiere einen eindeutigen Dateinamen
                    let fileName = url.lastPathComponent
                    let destinationURL = appFolder.appendingPathComponent(fileName)
                    
                    // Kopiere die Datei
                    try FileManager.default.copyItem(at: url, to: destinationURL)
                    
                    // Füge das Bild zur Liste hinzu
                    let newImage = CustomImage(name: url.deletingPathExtension().lastPathComponent, url: destinationURL)
                    customImages.append(newImage)
                    saveCustomImages()
                } catch {
                    showAlert(message: "Fehler beim Speichern des Bildes: \(error.localizedDescription)")
                }
            }
        }
    }
    
    func setCustomWallpaper(_ url: URL) {
        do {
            if let screen = NSScreen.main {
                try NSWorkspace.shared.setDesktopImageURL(url, for: screen)
            }
        } catch {
            showAlert(message: "Fehler beim Setzen des Hintergrunds: \(error.localizedDescription)")
        }
    }
    
    func selectFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        
        if panel.runModal() == .OK {
            selectedFolder = panel.url
        }
    }
    
    func setColorWallpaper(_ color: String) {
        guard let image = Bundle.main.url(forResource: color, withExtension: "png") else {
            showAlert(message: "Farbbild konnte nicht gefunden werden.")
            return
        }
        
        do {
            if let screen = NSScreen.main {
                try NSWorkspace.shared.setDesktopImageURL(image, for: screen)
            }
        } catch {
            showAlert(message: "Fehler beim Setzen des Hintergrunds: \(error.localizedDescription)")
        }
    }
    
    func changeWallpaper() {
        guard let folder = selectedFolder else {
            showAlert(message: "Bitte wähle zuerst einen Ordner aus.")
            return
        }
        
        do {
            let files = try FileManager.default.contentsOfDirectory(
                at: folder,
                includingPropertiesForKeys: nil
            )
            
            let imageFiles = files.filter { file in
                let ext = file.pathExtension.lowercased()
                return ["jpg", "jpeg", "png", "heic"].contains(ext)
            }
            
            guard !imageFiles.isEmpty else {
                showAlert(message: "Keine Bilder im ausgewählten Ordner gefunden.")
                return
            }
            
            if let randomImage = imageFiles.randomElement(),
               let screen = NSScreen.main {
                try NSWorkspace.shared.setDesktopImageURL(randomImage, for: screen)
            }
            
        } catch {
            showAlert(message: "Fehler beim Ändern des Hintergrundbilds: \(error.localizedDescription)")
        }
    }
    
    private func showAlert(message: String) {
        let alert = NSAlert()
        alert.messageText = message
        alert.alertStyle = .warning
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
}
