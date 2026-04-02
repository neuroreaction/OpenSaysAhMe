
import SwiftUI
import Intents
import CoreSpotlight

// MARK: - API Configuration
struct APIConfig {
    static var baseURL: String {
        get { UserDefaults.standard.string(forKey: "baseURL") ?? "http://PI.IP.HERE.0:5000" }
        set { UserDefaults.standard.set(newValue, forKey: "baseURL") }
    }
    
    static var apiToken: String {
        get { KeychainService.loadToken() ?? "" }
        set { KeychainService.saveToken(newValue) }
    }
}

// MARK: - Keychain Service
class KeychainService {
    static func saveToken(_ token: String) {
        let data = token.data(using: .utf8)!
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: "garage_api_token",
            kSecValueData as String: data
        ]
        SecItemDelete(query as CFDictionary)
        SecItemAdd(query as CFDictionary, nil)
    }
    
    static func loadToken() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: "garage_api_token",
            kSecReturnData as String: true
        ]
        var result: AnyObject?
        SecItemCopyMatching(query as CFDictionary, &result)
        if let data = result as? Data {
            return String(data: data, encoding: .utf8)
        }
        return nil
    }
}

// MARK: - Siri Intent Donation
class SiriIntentDonation {
    static func donateOpenDoorIntent(doorName: String, door: GarageDoorAPI.Door) {
        let activity = NSUserActivity(activityType: "com.garagedoor.open.\(door.rawValue)")
        activity.title = "Open \(doorName)"
        activity.userInfo = ["door": door.rawValue]
        activity.isEligibleForPrediction = true
        activity.isEligibleForSearch = true
        activity.persistentIdentifier = "open-\(door.rawValue)"
        
        let attributes = CSSearchableItemAttributeSet(contentType: .item)
        attributes.contentDescription = "Open \(doorName)"
        attributes.keywords = ["garage", "door", "open", doorName]
        activity.contentAttributeSet = attributes
        
        activity.suggestedInvocationPhrase = "Open \(doorName)"
        activity.becomeCurrent()
        
        print("Donated Siri shortcut for \(doorName)")
    }
}

// MARK: - API Service
class GarageDoorAPI: ObservableObject {
    enum Door: String {
        case left = "Left"
        case right = "Right"
    }
    
    enum APIError: LocalizedError {
        case invalidURL
        case unauthorized
        case networkError(String)
        case serverError(String)
        
        var errorDescription: String? {
            switch self {
            case .invalidURL:
                return "Invalid server URL"
            case .unauthorized:
                return "Invalid API token"
            case .networkError(let msg):
                return "Network error: \(msg)"
            case .serverError(let msg):
                return "Server error: \(msg)"
            }
        }
    }
    
    @Published var isConnected = false
    @Published var lastError: String?
    
    func triggerDoor(_ door: Door) async throws {
        let urlString = "\(APIConfig.baseURL)/api/trigger/\(door.rawValue)"
        
        guard let url = URL(string: urlString) else {
            throw APIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(APIConfig.apiToken)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 10
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw APIError.networkError("Invalid response")
            }
            
            if httpResponse.statusCode == 401 {
                throw APIError.unauthorized
            }
            
            if httpResponse.statusCode != 200 {
                let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
                throw APIError.serverError(errorMessage)
            }
            
        } catch let error as APIError {
            throw error
        } catch {
            throw APIError.networkError(error.localizedDescription)
        }
    }
    
    func checkConnection() async {
        let urlString = "\(APIConfig.baseURL)/health"
        
        guard let url = URL(string: urlString) else {
            await MainActor.run { self.isConnected = false }
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 5
        
        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            let success = (response as? HTTPURLResponse)?.statusCode == 200
            await MainActor.run { self.isConnected = success }
        } catch {
            await MainActor.run { self.isConnected = false }
        }
    }
}

// MARK: - Main Content View
struct ContentView: View {
    @StateObject private var api = GarageDoorAPI()
    @Environment(\.scenePhase) private var scenePhase
    @State private var showingSettings = false
    @State private var leftDoorName = UserDefaults.standard.string(forKey: "leftDoorName") ?? "Right Door"
    @State private var rightDoorName = UserDefaults.standard.string(forKey: "rightDoorName") ?? "Left Door"
    @State private var myDoor = UserDefaults.standard.string(forKey: "myDoor") ?? "left"
    @State private var activatingDoor: GarageDoorAPI.Door?
    @State private var showError = false
    @State private var timer: Timer?
    
    var body: some View {
        NavigationView {
            ZStack {
                LinearGradient(
                    colors: [Color(hex: "1a1a1a"), Color(hex: "2d2d2d")],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    HStack(spacing: 8) {
                        Circle()
                            .fill(api.isConnected ? Color.green : Color.red)
                            .frame(width: 10, height: 10)
                        Text(api.isConnected ? "Connected" : "Offline")
                            .font(.system(size: 14))
                            .foregroundColor(.gray)
                    }
                    .padding(.top, 20)
                    .padding(.bottom, 40)
                    
                    VStack(spacing: 24) {
                        DoorButton(
                            title: leftDoorName,
                            isMyDoor: myDoor == "left",
                            isActivating: activatingDoor == .left,
                            disabled: activatingDoor != nil
                        ) {
                            triggerDoor(.left, name: leftDoorName)
                        }
                        
                        DoorButton(
                            title: rightDoorName,
                            isMyDoor: myDoor == "right",
                            isActivating: activatingDoor == .right,
                            disabled: activatingDoor != nil
                        ) {
                            triggerDoor(.right, name: rightDoorName)
                        }
                    }
                    .padding(.horizontal, 24)
                    
                    Spacer()
                    
                    if let error = api.lastError {
                        Text(error)
                            .font(.system(size: 14))
                            .foregroundColor(.red)
                            .multilineTextAlignment(.center)
                            .padding()
                            .background(Color.red.opacity(0.1))
                            .cornerRadius(12)
                            .padding(.horizontal, 24)
                            .padding(.bottom, 20)
                    }
                }
            }
            .navigationTitle("OpenSaysAhMe")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingSettings = true }) {
                        Image(systemName: "gear")
                            .foregroundColor(.white)
                    }
                }
            }
            .sheet(isPresented: $showingSettings) {
                SettingsView(
                    leftDoorName: $leftDoorName,
                    rightDoorName: $rightDoorName,
                    myDoor: $myDoor
                )
            }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            INPreferences.requestSiriAuthorization { status in
                print("Siri authorization status: \(status.rawValue)")
            }
            startPolling()
        }
        .onChange(of: scenePhase) { phase in
            if phase == .active {
                startPolling()
            } else {
                stopPolling()
            }
        }
    }
    
    // MARK: - Polling
    private func startPolling() {
        stopPolling()
        Task { await api.checkConnection() }
        timer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { _ in
            Task { await api.checkConnection() }
        }
    }
    
    private func stopPolling() {
        timer?.invalidate()
        timer = nil
    }
    
    // MARK: - Door Trigger
    private func triggerDoor(_ door: GarageDoorAPI.Door, name: String) {
        guard activatingDoor == nil else { return }
        
        SiriIntentDonation.donateOpenDoorIntent(doorName: name, door: door)
        
        Task {
            activatingDoor = door
            api.lastError = nil
            
            do {
                try await api.triggerDoor(door)
                
                let generator = UINotificationFeedbackGenerator()
                generator.notificationOccurred(.success)
                
                try await Task.sleep(nanoseconds: 2_000_000_000)
                
            } catch {
                api.lastError = error.localizedDescription
            }
            
            activatingDoor = nil
        }
    }
}

// MARK: - Door Button Component
struct DoorButton: View {
    let title: String
    let isMyDoor: Bool
    let isActivating: Bool
    let disabled: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 12) {
                HStack {
                    Text(title)
                        .font(.system(size: 28, weight: .semibold))
                    if isMyDoor {
                        Image(systemName: "star.fill")
                            .font(.system(size: 16))
                            .foregroundColor(.yellow)
                    }
                }
                .foregroundColor(.white)
                
                Text(isActivating ? "Activating..." : (isMyDoor ? "My Door - Tap to Open" : "Tap to Open/Close"))
                    .font(.system(size: 14, weight: .regular))
                    .foregroundColor(.white.opacity(0.8))
            }
            .frame(maxWidth: .infinity)
            .frame(height: 160)
            .background(
                LinearGradient(
                    colors: isActivating ?
                        [Color(hex: "f093fb"), Color(hex: "f5576c")] :
                        (isMyDoor ?
                            [Color(hex: "4facfe"), Color(hex: "00f2fe")] :
                            [Color(hex: "667eea"), Color(hex: "764ba2")]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .cornerRadius(20)
            .shadow(color: .black.opacity(0.3), radius: 10, y: 5)
            .scaleEffect(isActivating ? 0.95 : 1.0)
            .opacity(disabled && !isActivating ? 0.6 : 1.0)
        }
        .disabled(disabled)
        .animation(.easeInOut(duration: 0.2), value: isActivating)
    }
}

// MARK: - Settings View
struct SettingsView: View {
    @Environment(\.presentationMode) var presentationMode
    @Binding var leftDoorName: String
    @Binding var rightDoorName: String
    @Binding var myDoor: String
    @State private var baseURL = APIConfig.baseURL
    @State private var apiToken = APIConfig.apiToken
    @State private var showTokenField = false
    
    var body: some View {
        NavigationView {
            ZStack {
                Color(hex: "1a1a1a").ignoresSafeArea()
                
                Form {
                    Section(header: Text("Server Configuration")) {
                        TextField("Server URL", text: $baseURL)
                            .autocapitalization(.none)
                            .keyboardType(.URL)
                        
                        HStack {
                            if showTokenField {
                                TextField("API Token", text: $apiToken)
                                    .autocapitalization(.none)
                            } else {
                                Text("API Token")
                                Spacer()
                                Text("••••••••")
                                    .foregroundColor(.gray)
                            }
                            Button(showTokenField ? "Hide" : "Show") {
                                showTokenField.toggle()
                            }
                            .font(.caption)
                        }
                    }
                    
                    Section(header: Text("Button Names")) {
                        TextField("Left Door Name", text: $leftDoorName)
                        TextField("Right Door Name", text: $rightDoorName)
                    }
                    
                    Section(header: Text("My Door (for Siri)")) {
                        Picker("My Door", selection: $myDoor) {
                            Text(leftDoorName).tag("left")
                            Text(rightDoorName).tag("right")
                        }
                        .pickerStyle(.segmented)
                        
                        Text("Siri will use this when you say 'Open my garage door'")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    
                    Section(header: Text("Siri Setup")) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("How to use Siri:")
                                .font(.headline)
                            Text("1. Set 'My Door' above")
                            Text("2. Tap 'Done' to save")
                            Text("3. Say: 'Hey Siri, open my garage door'")
                            Text("\nSiri is configured automatically when you save!")
                                .font(.caption)
                                .foregroundColor(.green)
                        }
                        .padding(.vertical, 4)
                    }
                    
                    Section(header: Text("About")) {
                        HStack {
                            Text("Version")
                            Spacer()
                            Text("2.1")
                                .foregroundColor(.gray)
                        }
                        HStack {
                            Text("Siri Support")
                            Spacer()
                            Text("✓")
                                .foregroundColor(.green)
                        }
                        HStack {
                            Text("Real-time Status")
                            Spacer()
                            Text("✓")
                                .foregroundColor(.green)
                        }
                    }
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        saveSettings()
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
        }
        .preferredColorScheme(.dark)
    }
    
    private func saveSettings() {
        APIConfig.baseURL = baseURL
        APIConfig.apiToken = apiToken
        UserDefaults.standard.set(leftDoorName, forKey: "leftDoorName")
        UserDefaults.standard.set(rightDoorName, forKey: "rightDoorName")
        UserDefaults.standard.set(myDoor, forKey: "myDoor")
        
        let doorToUse: GarageDoorAPI.Door = myDoor == "left" ? .left : .right
        let doorName = myDoor == "left" ? leftDoorName : rightDoorName
        SiriIntentDonation.donateOpenDoorIntent(doorName: "my garage door", door: doorToUse)
    }
}

// MARK: - Color Extension
extension Color {
    init(hex: String) {
        let scanner = Scanner(string: hex)
        var rgbValue: UInt64 = 0
        scanner.scanHexInt64(&rgbValue)
        
        let r = Double((rgbValue & 0xFF0000) >> 16) / 255.0
        let g = Double((rgbValue & 0x00FF00) >> 8) / 255.0
        let b = Double(rgbValue & 0x0000FF) / 255.0
        
        self.init(red: r, green: g, blue: b)
    }
}

// MARK: - Preview
struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
