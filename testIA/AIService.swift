import Foundation
import Combine

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
        case .claude: return "claude-opus-4-7 - Anthropic"
        case .deepseek: return "deepseek-v4-pro - Open Source"
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
    private let model = "claude-opus-4-7"
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
                    request.timeoutInterval = 60 // Timeout de 60 segundos
                    
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
                    
                    print("🔵 Claude: Enviando petición...")
                    let (bytes, response) = try await URLSession.shared.bytes(for: request)
                    
                    guard let httpResponse = response as? HTTPURLResponse else {
                        throw AIServiceError.invalidResponse
                    }
                    
                    print("🔵 Claude: Status Code \(httpResponse.statusCode)")
                    
                    // Verificar código de estado
                    if httpResponse.statusCode != 200 {
                        // Leer el cuerpo completo del error
                        var errorLines: [String] = []
                        for try await line in bytes.lines {
                            errorLines.append(line)
                        }
                        let errorBody = errorLines.joined(separator: "\n")
                        print("🔴 Claude Error Body: \(errorBody)")
                        
                        // Intentar parsear el error
                        if let errorData = errorBody.data(using: .utf8),
                           let json = try? JSONSerialization.jsonObject(with: errorData) as? [String: Any],
                           let error = json["error"] as? [String: Any],
                           let errorMessage = error["message"] as? String {
                            throw NSError(domain: "ClaudeError", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: errorMessage])
                        }
                        
                        throw AIServiceError.httpError(httpResponse.statusCode)
                    }
                    
                    var accumulatedText = ""
                    var hasReceivedData = false
                    
                    print("🔵 Claude: Procesando stream...")
                    
                    for try await line in bytes.lines {
                        // Ignorar líneas vacías
                        if line.trimmingCharacters(in: .whitespaces).isEmpty {
                            continue
                        }
                        
                        // Verificar si es un evento SSE
                        if line.hasPrefix("event:") {
                            print("🔵 Claude Event: \(line)")
                            continue
                        }
                        
                        // Procesar datos
                        if line.hasPrefix("data: ") {
                            let jsonString = String(line.dropFirst(6))
                            
                            print("🔵 Claude Data: \(jsonString.prefix(100))...")
                            
                            // Ignorar eventos vacíos
                            if jsonString.trimmingCharacters(in: .whitespaces).isEmpty {
                                continue
                            }
                            
                            guard let data = jsonString.data(using: .utf8),
                                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                                print("⚠️ Claude: No se pudo parsear JSON")
                                continue
                            }
                            
                            // Procesar eventos de streaming de Claude
                            if let type = json["type"] as? String {
                                print("🔵 Claude Type: \(type)")
                                
                                switch type {
                                case "message_start":
                                    print("✅ Claude: Mensaje iniciado")
                                    
                                case "content_block_start":
                                    print("✅ Claude: Bloque de contenido iniciado")
                                    
                                case "content_block_delta":
                                    // Delta con texto nuevo
                                    if let delta = json["delta"] as? [String: Any],
                                       let deltaType = delta["type"] as? String,
                                       deltaType == "text_delta",
                                       let text = delta["text"] as? String {
                                        accumulatedText += text
                                        hasReceivedData = true
                                        continuation.yield(accumulatedText)
                                        print("✅ Claude: Texto recibido (\(text.count) chars)")
                                    }
                                    
                                case "content_block_stop":
                                    print("✅ Claude: Bloque de contenido finalizado")
                                    
                                case "message_delta":
                                    print("✅ Claude: Delta del mensaje")
                                    
                                case "message_stop":
                                    print("✅ Claude: Mensaje completado")
                                    continuation.finish()
                                    return
                                    
                                case "error":
                                    if let error = json["error"] as? [String: Any],
                                       let message = error["message"] as? String {
                                        print("🔴 Claude Error: \(message)")
                                        throw NSError(domain: "ClaudeError", code: 0, userInfo: [NSLocalizedDescriptionKey: message])
                                    }
                                    
                                default:
                                    print("⚠️ Claude: Tipo desconocido: \(type)")
                                }
                            }
                        }
                    }
                    
                    print("🔵 Claude: Stream finalizado. Datos recibidos: \(hasReceivedData)")
                    
                    // Si no recibimos ningún dato, lanzar error
                    if !hasReceivedData {
                        throw NSError(domain: "ClaudeError", code: 0, userInfo: [NSLocalizedDescriptionKey: "No se recibió respuesta del servidor"])
                    }
                    
                    // Si llegamos aquí sin recibir message_stop, aún así terminamos
                    continuation.finish()
                } catch {
                    print("🔴 Claude Error: \(error.localizedDescription)")
                    continuation.finish(throwing: error)
                }
            }
        }
    }
}

// MARK: - Servicio de DeepSeek
class DeepSeekService: AIService {
    private let apiKey: String
    private let model = "deepseek-v4-pro"
    private let baseURL = "https://api.deepseek.com/chat/completions"
    
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
                        "stream": true
                    ]
                    
                    request.httpBody = try JSONSerialization.data(withJSONObject: body)
                    
                    let (bytes, response) = try await URLSession.shared.bytes(for: request)
                    
                    guard let httpResponse = response as? HTTPURLResponse else {
                        throw AIServiceError.invalidResponse
                    }
                    
                    // Mejor manejo de errores
                    if httpResponse.statusCode != 200 {
                        // Intentar leer el mensaje de error
                        var errorMessage = "Error HTTP: \(httpResponse.statusCode)"
                        for try await line in bytes.lines {
                            if let data = line.data(using: .utf8),
                               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                                if let error = json["error"] as? [String: Any],
                                   let message = error["message"] as? String {
                                    errorMessage = "\(errorMessage) - \(message)"
                                }
                                break
                            }
                        }
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
