import Foundation

// MARK: - Proveedor de IA
enum AIProvider: String, CaseIterable, Identifiable {
    case appleIntelligence = "Apple Intelligence"
    case claude = "Claude"
    case deepseek = "DeepSeek"
    
    var id: String { rawValue }
    
    var icon: String {
        switch self {
        case .appleIntelligence: return "apple.logo"
        case .claude: return "brain.head.profile"
        case .deepseek: return "sparkles"
        }
    }
    
    var description: String {
        switch self {
        case .appleIntelligence: return "On-device, privado"
        case .claude: return "Claude 3.5 Sonnet - Anthropic"
        case .deepseek: return "DeepSeek R1 - Open Source"
        }
    }
    
    var requiresAPIKey: Bool {
        switch self {
        case .appleIntelligence: return false
        case .claude, .deepseek: return true
        }
    }
}

// MARK: - Protocolo de Servicio de IA
protocol AIService {
    func sendMessage(_ message: String, instructions: String) async throws -> AsyncThrowingStream<String, Error>
}

// MARK: - Servicio de Claude (Anthropic)
class ClaudeService: AIService {
    private let apiKey: String
    private let model = "claude-3-5-sonnet-20241022"
    private let baseURL = "https://api.anthropic.com/v1/messages"
    
    init(apiKey: String) {
        self.apiKey = apiKey
    }
    
    func sendMessage(_ message: String, instructions: String) async throws -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    guard let url = URL(string: baseURL) else {
                        throw AIServiceError.invalidURL
                    }
                    
                    var request = URLRequest(url: url)
                    request.httpMethod = "POST"
                    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                    request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
                    request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
                    
                    let body: [String: Any] = [
                        "model": model,
                        "max_tokens": 4096,
                        "system": instructions,
                        "messages": [
                            ["role": "user", "content": message]
                        ],
                        "stream": true
                    ]
                    
                    request.httpBody = try JSONSerialization.data(withJSONObject: body)
                    
                    let (bytes, response) = try await URLSession.shared.bytes(for: request)
                    
                    guard let httpResponse = response as? HTTPURLResponse else {
                        throw AIServiceError.invalidResponse
                    }
                    
                    guard httpResponse.statusCode == 200 else {
                        throw AIServiceError.httpError(httpResponse.statusCode)
                    }
                    
                    var accumulatedText = ""
                    
                    for try await line in bytes.lines {
                        if line.hasPrefix("data: ") {
                            let jsonString = String(line.dropFirst(6))
                            
                            if jsonString == "[DONE]" {
                                continuation.finish()
                                return
                            }
                            
                            guard let data = jsonString.data(using: .utf8),
                                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                                continue
                            }
                            
                            // Procesar eventos de streaming de Claude
                            if let type = json["type"] as? String {
                                switch type {
                                case "content_block_delta":
                                    if let delta = json["delta"] as? [String: Any],
                                       let text = delta["text"] as? String {
                                        accumulatedText += text
                                        continuation.yield(accumulatedText)
                                    }
                                case "message_stop":
                                    continuation.finish()
                                    return
                                default:
                                    break
                                }
                            }
                        }
                    }
                    
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }
}

// MARK: - Servicio de DeepSeek
class DeepSeekService: AIService {
    private let apiKey: String
    private let model = "deepseek-chat"
    private let baseURL = "https://api.deepseek.com/v1/chat/completions"
    
    init(apiKey: String) {
        self.apiKey = apiKey
    }
    
    func sendMessage(_ message: String, instructions: String) async throws -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    guard let url = URL(string: baseURL) else {
                        throw AIServiceError.invalidURL
                    }
                    
                    var request = URLRequest(url: url)
                    request.httpMethod = "POST"
                    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                    request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
                    
                    let body: [String: Any] = [
                        "model": model,
                        "messages": [
                            ["role": "system", "content": instructions],
                            ["role": "user", "content": message]
                        ],
                        "stream": true,
                        "max_tokens": 4096,
                        "temperature": 0.7
                    ]
                    
                    request.httpBody = try JSONSerialization.data(withJSONObject: body)
                    
                    let (bytes, response) = try await URLSession.shared.bytes(for: request)
                    
                    guard let httpResponse = response as? HTTPURLResponse else {
                        throw AIServiceError.invalidResponse
                    }
                    
                    guard httpResponse.statusCode == 200 else {
                        throw AIServiceError.httpError(httpResponse.statusCode)
                    }
                    
                    var accumulatedText = ""
                    
                    for try await line in bytes.lines {
                        if line.hasPrefix("data: ") {
                            let jsonString = String(line.dropFirst(6))
                            
                            if jsonString == "[DONE]" {
                                continuation.finish()
                                return
                            }
                            
                            guard let data = jsonString.data(using: .utf8),
                                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                                continue
                            }
                            
                            // Procesar eventos de streaming de DeepSeek (formato OpenAI compatible)
                            if let choices = json["choices"] as? [[String: Any]],
                               let firstChoice = choices.first,
                               let delta = firstChoice["delta"] as? [String: Any],
                               let content = delta["content"] as? String {
                                accumulatedText += content
                                continuation.yield(accumulatedText)
                            }
                        }
                    }
                    
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }
}

// MARK: - Errores del Servicio de IA
enum AIServiceError: LocalizedError {
    case invalidURL
    case invalidResponse
    case httpError(Int)
    case noAPIKey
    case decodingError
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "URL inválida"
        case .invalidResponse:
            return "Respuesta inválida del servidor"
        case .httpError(let code):
            return "Error HTTP: \(code)"
        case .noAPIKey:
            return "No se ha configurado la API key"
        case .decodingError:
            return "Error al decodificar la respuesta"
        }
    }
}

// MARK: - Gestor de API Keys
class APIKeyManager: ObservableObject {
    @Published var claudeAPIKey: String {
        didSet {
            UserDefaults.standard.set(claudeAPIKey, forKey: "claudeAPIKey")
        }
    }
    
    @Published var deepseekAPIKey: String {
        didSet {
            UserDefaults.standard.set(deepseekAPIKey, forKey: "deepseekAPIKey")
        }
    }
    
    init() {
        self.claudeAPIKey = UserDefaults.standard.string(forKey: "claudeAPIKey") ?? ""
        self.deepseekAPIKey = UserDefaults.standard.string(forKey: "deepseekAPIKey") ?? ""
    }
    
    func getAPIKey(for provider: AIProvider) -> String? {
        switch provider {
        case .appleIntelligence:
            return nil
        case .claude:
            return claudeAPIKey.isEmpty ? nil : claudeAPIKey
        case .deepseek:
            return deepseekAPIKey.isEmpty ? nil : deepseekAPIKey
        }
    }
    
    func hasAPIKey(for provider: AIProvider) -> Bool {
        if !provider.requiresAPIKey { return true }
        return getAPIKey(for: provider) != nil
    }
}
