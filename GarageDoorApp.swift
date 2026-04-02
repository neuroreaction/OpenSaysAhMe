// Garage Door Controller - iOS App Example
// Swift 5+ for iOS 14+

import SwiftUI
import Combine

// MARK: - Configuration
struct Config {
    static let baseURL = "http://192.168.1.XXX:5000"  // Change to your Pi's IP
    static let apiToken = "YOUR_API_TOKEN_HERE"       // Add your token
}

// MARK: - API Service
class GarageDoorAPI {
    static let shared = GarageDoorAPI()
    
    enum Door: String {
        case sara = "sara"
        case dave = "dave"
    }
    
    enum APIError: Error {
        case invalidURL
        case networkError(Error)
        case unauthorized
        case serverError(String)
    }
    
    func triggerDoor(_ door: Door) async throws {
        guard let url = URL(string: "\(Config.baseURL)/api/trigger/\(door.rawValue)") else {
            throw APIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(Config.apiToken)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 10
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw APIError.networkError(NSError(domain: "", code: -1))
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
            throw APIError.networkError(error)
        }
    }
    
    func checkStatus() async throws -> Bool {
        guard let url = URL(string: "\(Config.baseURL)/api/status") else {
            throw APIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(Config.apiToken)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 5
        
        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                return false
            }
            return httpResponse.statusCode == 200
        } catch {
            return false
        }
    }
}

// MARK: - View Model
@MainActor
class GarageDoorViewModel: ObservableObject {
    @Published var isConnected: Bool = false
    @Published var isActivating: Bool = false
    @Published var lastError: String?
    @Published var activatingDoor: GarageDoorAPI.Door?
    
    private let api = GarageDoorAPI.shared
    
    func checkConnection() {
        Task {
            isConnected = (try? await api.checkStatus()) ?? false
        }
    }
    
    func triggerDoor(_ door: GarageDoorAPI.Door) {
        guard !isActivating else { return }
        
        Task {
            isActivating = true
            activatingDoor = door
            lastError = nil
            
            do {
                try await api.triggerDoor(door)
                
                // Haptic feedback
                let generator = UINotificationFeedbackGenerator()
                generator.notificationOccurred(.success)
                
                // Keep button in activating state for visual feedback
                try await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
                
            } catch GarageDoorAPI.APIError.unauthorized {
                lastError = "Unauthorized - Check your API token"
            } catch GarageDoorAPI.APIError.serverError(let message) {
                lastError = "Server error: \(message)"
            } catch {
                lastError = "Network error: \(error.localizedDescription)"
            }
            
            isActivating = false
            activatingDoor = nil
        }
    }
}

// MARK: - Main View
struct ContentView: View {
    @StateObject private var viewModel = GarageDoorViewModel()
    
    var body: some View {
        ZStack {
            // Background
            LinearGradient(
                colors: [Color(hex: "1a1a1a"), Color(hex: "2d2d2d")],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header
                VStack(spacing: 8) {
                    Text("🚗 Garage Doors")
                        .font(.system(size: 32, weight: .bold))
                        .foregroundColor(.white)
                    
                    HStack(spacing: 6) {
                        Circle()
                            .fill(viewModel.isConnected ? Color.green : Color.red)
                            .frame(width: 8, height: 8)
                        
                        Text(viewModel.isConnected ? "Connected" : "Offline")
                            .font(.system(size: 14))
                            .foregroundColor(.gray)
                    }
                }
                .padding(.top, 60)
                .padding(.bottom, 40)
                
                // Door Buttons
                VStack(spacing: 24) {
                    DoorButton(
                        title: "Sara's Door",
                        isActivating: viewModel.activatingDoor == .sara,
                        disabled: viewModel.isActivating
                    ) {
                        viewModel.triggerDoor(.sara)
                    }
                    
                    DoorButton(
                        title: "David's Door",
                        isActivating: viewModel.activatingDoor == .dave,
                        disabled: viewModel.isActivating
                    ) {
                        viewModel.triggerDoor(.dave)
                    }
                }
                .padding(.horizontal, 24)
                
                Spacer()
                
                // Error Message
                if let error = viewModel.lastError {
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
        .onAppear {
            viewModel.checkConnection()
        }
    }
}

// MARK: - Door Button Component
struct DoorButton: View {
    let title: String
    let isActivating: Bool
    let disabled: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 12) {
                Text(title)
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundColor(.white)
                
                Text(isActivating ? "Activating..." : "Tap to Open/Close")
                    .font(.system(size: 14, weight: .regular))
                    .foregroundColor(.white.opacity(0.8))
            }
            .frame(maxWidth: .infinity)
            .frame(height: 160)
            .background(
                LinearGradient(
                    colors: isActivating ?
                        [Color(hex: "f093fb"), Color(hex: "f5576c")] :
                        [Color(hex: "667eea"), Color(hex: "764ba2")],
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

// MARK: - App Entry Point
@main
struct GarageDoorApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

/*
 SETUP INSTRUCTIONS:
 ===================
 
 1. Create new iOS App project in Xcode
 2. Replace ContentView.swift with this code
 3. Update Config struct with:
    - Your Raspberry Pi's IP address
    - Your API token from config.json
 4. Add required capabilities if needed (Network)
 5. Test on local network first
 
 DEPLOYMENT NOTES:
 - For App Store: Need proper domain with HTTPS
 - For TestFlight: Works with local IP for testing
 - Consider adding: biometric auth, widgets, notifications
 
 SECURITY:
 - Store token in Keychain for production
 - Use HTTPS for internet access
 - Implement certificate pinning for extra security
 */
