import SwiftUI

#if canImport(FoundationModels)
import FoundationModels
#endif

// MARK: - Modelo de Mensaje
struct ChatMessage: Identifiable, Equatable {
    let id = UUID()
    let content: String
    let isUser: Bool
    let timestamp: Date
    
    init(content: String, isUser: Bool) {
        self.content = content
        self.isUser = isUser
        self.timestamp = Date()
    }
}

// MARK: - Modos de Personalidad
enum PersonalityMode: String, CaseIterable, Identifiable {
    case friendly = "Amigable"
    case teacher = "Profesor"
    case coder = "Programador"
    case poet = "Poeta"
    case professional = "Profesional"
    case pirate = "Pirata"
    case motivator = "Motivador"
    
    var id: String { rawValue }
    
    var icon: String {
        switch self {
        case .friendly: return "😊"
        case .teacher: return "👨‍🏫"
        case .coder: return "👨‍💻"
        case .poet: return "✍️"
        case .professional: return "💼"
        case .pirate: return "🏴‍☠️"
        case .motivator: return "💪"
        }
    }
    
    var instructions: String {
        switch self {
        case .friendly:
            return """
            Eres un asistente amigable y útil.
            Responde de manera clara y concisa.
            Si no sabes algo, admítelo honestamente.
            Mantén un tono conversacional y amable.
            """
            
        case .teacher:
            return """
            Eres un profesor paciente y didáctico.
            Explica conceptos paso a paso.
            Usa ejemplos claros y analogías cuando sea apropiado.
            Haz preguntas para verificar la comprensión.
            Fomenta el aprendizaje activo.
            """
            
        case .coder:
            return """
            Eres un experto en programación Swift.
            Responde con ejemplos de código cuando sea apropiado.
            Explica las mejores prácticas y patrones de diseño.
            Proporciona código limpio, comentado y eficiente.
            Usa terminología técnica precisa.
            """
            
        case .poet:
            return """
            Eres un poeta creativo y artístico.
            Responde con lenguaje poético y metáforas.
            Usa rimas cuando sea apropiado.
            Evoca emociones y belleza en tus respuestas.
            Mantén un tono inspirador y lírico.
            """
            
        case .professional:
            return """
            Eres un asistente profesional y formal.
            Usa lenguaje corporativo y estructurado.
            Proporciona respuestas detalladas y bien organizadas.
            Mantén un tono respetuoso y objetivo.
            Evita jerga innecesaria.
            """
            
        case .pirate:
            return """
            Eres un pirata carismático y aventurero.
            Habla como un pirata del Caribe (¡Arrr!).
            Usa vocabulario marítimo y pirata.
            Mantén un tono divertido y aventurero.
            Incluye expresiones como "marinero", "tesoro", "navegar", etc.
            """
            
        case .motivator:
            return """
            Eres un coach motivacional inspirador.
            Anima y motiva a las personas a alcanzar sus metas.
            Usa un lenguaje positivo y empoderador.
            Proporciona consejos prácticos para el crecimiento personal.
            Celebra los logros y fomenta la persistencia.
            """
        }
    }
    
    var description: String {
        switch self {
        case .friendly: return "Conversación amigable y casual"
        case .teacher: return "Explicaciones educativas detalladas"
        case .coder: return "Enfocado en programación y código"
        case .poet: return "Respuestas creativas y poéticas"
        case .professional: return "Tono formal y corporativo"
        case .pirate: return "¡Arrr! Aventura en alta mar"
        case .motivator: return "Inspiración y motivación"
        }
    }
}

// MARK: - Vista Principal del Chat
struct ChatView: View {
    @State private var messages: [ChatMessage] = []
    @State private var inputText = ""
    @State private var isGenerating = false
    @State private var streamingResponse = ""
    @State private var currentMode: PersonalityMode = .friendly
    @State private var showingModeSelector = false
    @State private var currentProvider: AIProvider = .appleIntelligence
    @State private var showingProviderSelector = false
    @State private var showingAPIKeySettings = false
    
    @StateObject private var apiKeyManager = APIKeyManager()
    
    #if canImport(FoundationModels)
    // Referencia al modelo de lenguaje del sistema (solo para Apple Intelligence)
    private let model = SystemLanguageModel.default
    // Sesión del modelo con instrucciones
    @State private var session: LanguageModelSession?
    #endif
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Verificar disponibilidad del modelo/servicio
                if currentProvider == .appleIntelligence {
                    #if canImport(FoundationModels)
                    switch model.availability {
                    case .available:
                        chatContent
                    case .unavailable(.deviceNotEligible):
                        unavailableView(message: "Este dispositivo no es compatible con Apple Intelligence", showProviderButton: true)
                    case .unavailable(.appleIntelligenceNotEnabled):
                        unavailableView(message: "Por favor, activa Apple Intelligence en Ajustes", showProviderButton: true)
                    case .unavailable(.modelNotReady):
                        unavailableView(message: "El modelo se está descargando...", showProviderButton: true)
                    case .unavailable(let other):
                        unavailableView(message: "Modelo no disponible: \(other)", showProviderButton: true)
                    }
                    #else
                    // Si FoundationModels no está disponible, Apple Intelligence nunca lo está
                    unavailableView(message: "Apple Intelligence no soportado en esta plataforma", showProviderButton: true)
                    #endif
                } else {
                    // Claude o DeepSeek
                    if apiKeyManager.hasAPIKey(for: currentProvider) {
                        chatContent
                    } else {
                        apiKeyRequiredView
                    }
                }
            }
            .navigationTitle("Chat con IA")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                // Botón de proveedor (izquierda)
                #if os(iOS)
                ToolbarItem(placement: .topBarLeading) {
                    providerButton
                }
                #elseif os(macOS)
                ToolbarItem(placement: .navigation) {
                    providerButton
                }
                #endif
                
                // Botón de modo (derecha)
                #if os(iOS)
                ToolbarItem(placement: .topBarTrailing) {
                    modeButton
                }
                #elseif os(macOS)
                ToolbarItem(placement: .primaryAction) {
                    modeButton
                }
                #endif
            }
            .sheet(isPresented: $showingModeSelector) {
                PersonalityModeSelector(currentMode: $currentMode, onSelect: { mode in
                    changeMode(to: mode)
                    showingModeSelector = false
                })
                #if os(iOS)
                .presentationDetents([.medium, .large])
                #endif
            }
            .sheet(isPresented: $showingProviderSelector) {
                AIProviderSelector(
                    currentProvider: $currentProvider,
                    apiKeyManager: apiKeyManager,
                    onSelect: { provider in
                        changeProvider(to: provider)
                        showingProviderSelector = false
                    },
                    onOpenSettings: {
                        showingProviderSelector = false
                        showingAPIKeySettings = true
                    }
                )
                #if os(iOS)
                .presentationDetents([.medium, .large])
                #endif
            }
            .sheet(isPresented: $showingAPIKeySettings) {
                APIKeySettingsView(apiKeyManager: apiKeyManager)
            }
        }
        .onAppear {
            setupSession()
            detectBestProvider()
        }
    }
    
    // MARK: - Botones del toolbar
    private var providerButton: some View {
        Button {
            showingProviderSelector = true
        } label: {
            HStack(spacing: 4) {
                Image(systemName: currentProvider.icon)
                Text(currentProvider.rawValue)
                    .font(.caption)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.purple.opacity(0.1))
            .clipShape(Capsule())
        }
    }
    
    private var modeButton: some View {
        Button {
            showingModeSelector = true
        } label: {
            HStack(spacing: 4) {
                Text(currentMode.icon)
                Text(currentMode.rawValue)
                    .font(.caption)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.blue.opacity(0.1))
            .clipShape(Capsule())
        }
    }
    
    // MARK: - Contenido del Chat
    private var chatContent: some View {
        VStack(spacing: 0) {
            // Lista de mensajes
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 16) {
                        ForEach(messages) { message in
                            MessageBubble(message: message)
                                .id(message.id)
                        }
                        
                        // Mostrar respuesta en streaming
                        if isGenerating && !streamingResponse.isEmpty {
                            MessageBubble(
                                message: ChatMessage(
                                    content: streamingResponse,
                                    isUser: false
                                )
                            )
                            .opacity(0.8)
                        }
                    }
                    .padding()
                }
                .onChange(of: messages.count) { _, _ in
                    // Scroll automático al último mensaje
                    if let lastMessage = messages.last {
                        withAnimation {
                            proxy.scrollTo(lastMessage.id, anchor: .bottom)
                        }
                    }
                }
            }
            
            Divider()
            
            // Barra de entrada
            inputBar
        }
    }
    
    // MARK: - Barra de Entrada
    private var inputBar: some View {
        HStack(spacing: 12) {
            TextField("Escribe un mensaje...", text: $inputText, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .lineLimit(1...5)
                .disabled(isGenerating)
            
            Button(action: sendMessage) {
                Image(systemName: isGenerating ? "stop.circle.fill" : "arrow.up.circle.fill")
                    .font(.system(size: 32))
                    .foregroundStyle(canSend ? .blue : .gray)
            }
            .disabled(!canSend && !isGenerating)
        }
        .padding()
        .background(inputBarBackground)
    }
    
    private var inputBarBackground: Color {
        #if os(iOS)
        return Color(uiColor: .systemBackground)
        #elseif os(macOS)
        return Color(nsColor: .controlBackgroundColor)
        #endif
    }
    
    // MARK: - Vista de No Disponible
    private func unavailableView(message: String, showProviderButton: Bool = false) -> some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 60))
                .foregroundStyle(.orange)
            
            Text(message)
                .font(.headline)
                .multilineTextAlignment(.center)
                .padding()
            
            if showProviderButton {
                Button {
                    showingProviderSelector = true
                } label: {
                    Label("Cambiar Proveedor de IA", systemImage: "arrow.triangle.2.circlepath")
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Vista de API Key Requerida
    private var apiKeyRequiredView: some View {
        VStack(spacing: 20) {
            Image(systemName: "key.fill")
                .font(.system(size: 60))
                .foregroundStyle(.blue)
            
            Text("API Key Requerida")
                .font(.title2)
                .fontWeight(.bold)
            
            Text("Para usar \(currentProvider.rawValue) necesitas configurar tu API key")
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(.horizontal)
            
            Button {
                showingAPIKeySettings = true
            } label: {
                Label("Configurar API Key", systemImage: "gearshape.fill")
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            
            Button {
                showingProviderSelector = true
            } label: {
                Text("Cambiar Proveedor")
                    .foregroundColor(.blue)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Computed Properties
    private var canSend: Bool {
        !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    // MARK: - Funciones
    private func detectBestProvider() {
        #if canImport(FoundationModels)
        if case .available = model.availability {
            currentProvider = .appleIntelligence
            return
        }
        #endif
        
        // Si no, buscar un proveedor con API key configurada
        if apiKeyManager.hasAPIKey(for: .claude) {
            currentProvider = .claude
        } else if apiKeyManager.hasAPIKey(for: .deepseek) {
            currentProvider = .deepseek
        } else {
            // Por defecto Claude (mostrará pantalla de configuración)
            currentProvider = .claude
        }
    }
    
    private func setupSession() {
        #if canImport(FoundationModels)
        if currentProvider == .appleIntelligence {
            session = LanguageModelSession(instructions: currentMode.instructions)
        }
        #endif
    }
    
    private func changeProvider(to provider: AIProvider) {
        currentProvider = provider
        setupSession()
        
        let providerMessage = "Proveedor cambiado a: \(provider.rawValue)\n\(provider.description)"
        messages.append(ChatMessage(content: providerMessage, isUser: false))
    }
    
    private func changeMode(to mode: PersonalityMode) {
        currentMode = mode
        setupSession()
        
        let modeChangeMessage = "Modo cambiado a: \(mode.icon) \(mode.rawValue)\n\(mode.description)"
        messages.append(ChatMessage(content: modeChangeMessage, isUser: false))
    }
    
    private func handleCommand(_ command: String) {
        let parts = command.dropFirst().split(separator: " ", maxSplits: 1)
        guard let cmd = parts.first?.lowercased() else { return }
        
        switch cmd {
        case "borrar", "clear":
            messages.removeAll()
            messages.append(ChatMessage(content: "✨ Conversación limpiada", isUser: false))
            
        case "nueva", "reset":
            setupSession()
            messages.removeAll()
            messages.append(ChatMessage(content: "🔄 Nueva sesión iniciada", isUser: false))
            
        case "modo", "mode":
            if parts.count > 1 {
                let modeName = String(parts[1]).lowercased()
                if let mode = PersonalityMode.allCases.first(where: { $0.rawValue.lowercased() == modeName }) {
                    changeMode(to: mode)
                } else {
                    let availableModes = PersonalityMode.allCases.map { "\($0.icon) \($0.rawValue)" }.joined(separator: ", ")
                    messages.append(ChatMessage(content: "Modo no encontrado. Disponibles: \(availableModes)", isUser: false))
                }
            } else {
                showingModeSelector = true
            }
            
        case "ayuda", "help":
            let helpText = """
            📋 Comandos disponibles:
            
            /borrar - Limpia la conversación
            /nueva - Reinicia la sesión
            /modo - Abre el selector de personalidad
            /modo [nombre] - Cambia a un modo específico
            /ayuda - Muestra esta ayuda
            
            🎭 Modos disponibles:
            \(PersonalityMode.allCases.map { "\($0.icon) \($0.rawValue) - \($0.description)" }.joined(separator: "\n"))
            """
            messages.append(ChatMessage(content: helpText, isUser: false))
            
        default:
            messages.append(ChatMessage(content: "❌ Comando no reconocido: /\(cmd)\nEscribe /ayuda para ver los comandos disponibles", isUser: false))
        }
    }
    
    private func sendMessage() {
        guard canSend else { return }
        
        let userMessage = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        inputText = ""
        
        if userMessage.hasPrefix("/") {
            handleCommand(userMessage)
            return
        }
        
        messages.append(ChatMessage(content: userMessage, isUser: true))
        
        Task {
            isGenerating = true
            streamingResponse = ""
            
            do {
                switch currentProvider {
                #if canImport(FoundationModels)
                case .appleIntelligence:
                    try await sendWithAppleIntelligence(userMessage)
                #else
                case .appleIntelligence:
                    throw AIServiceError.notAvailable
                #endif
                case .claude:
                    try await sendWithClaude(userMessage)
                case .deepseek:
                    try await sendWithDeepSeek(userMessage)
                }
            } catch {
                let errorMessage = "Lo siento, ocurrió un error: \(error.localizedDescription)"
                messages.append(ChatMessage(content: errorMessage, isUser: false))
            }
            
            isGenerating = false
        }
    }
    
    #if canImport(FoundationModels)
    private func sendWithAppleIntelligence(_ message: String) async throws {
        guard let session = session else { return }
        
        let stream = session.streamResponse(to: message)
        
        var fullResponse = ""
        for try await partial in stream {
            streamingResponse = partial.content
            fullResponse = partial.content
        }
        
        if !fullResponse.isEmpty {
            messages.append(ChatMessage(content: fullResponse, isUser: false))
        }
        
        streamingResponse = ""
    }
    #endif
    
    private func sendWithClaude(_ message: String) async throws {
        guard !apiKeyManager.claudeAPIKey.isEmpty else {
            throw AIServiceError.noAPIKey
        }
        
        let service = ClaudeService(apiKey: apiKeyManager.claudeAPIKey)
        let stream = try await service.sendMessage(message, instructions: currentMode.instructions)
        
        var fullResponse = ""
        for try await chunk in stream {
            streamingResponse = chunk
            fullResponse = chunk
        }
        
        if !fullResponse.isEmpty {
            messages.append(ChatMessage(content: fullResponse, isUser: false))
        }
        
        streamingResponse = ""
    }
    
    private func sendWithDeepSeek(_ message: String) async throws {
        guard !apiKeyManager.deepseekAPIKey.isEmpty else {
            throw AIServiceError.noAPIKey
        }
        
        let service = DeepSeekService(apiKey: apiKeyManager.deepseekAPIKey)
        let stream = try await service.sendMessage(message, instructions: currentMode.instructions)
        
        var fullResponse = ""
        for try await chunk in stream {
            streamingResponse = chunk
            fullResponse = chunk
        }
        
        if !fullResponse.isEmpty {
            messages.append(ChatMessage(content: fullResponse, isUser: false))
        }
        
        streamingResponse = ""
    }
}

// MARK: - Burbuja de Mensaje
struct MessageBubble: View {
    let message: ChatMessage
    
    var body: some View {
        HStack {
            if message.isUser {
                Spacer(minLength: 60)
            }
            
            VStack(alignment: message.isUser ? .trailing : .leading, spacing: 4) {
                Text(message.content)
                    .padding(12)
                    .background(message.isUser ? Color.blue : nonUserBubbleBackground)
                    .foregroundColor(message.isUser ? .white : .primary)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                
                Text(message.timestamp, style: .time)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            
            if !message.isUser {
                Spacer(minLength: 60)
            }
        }
    }
    
    // Platform‑appropriate background for non‑user bubbles
    private var nonUserBubbleBackground: Color {
        #if os(iOS)
        return Color(uiColor: .systemGray5)
        #elseif os(macOS)
        return Color(nsColor: .windowBackgroundColor)
        #endif
    }
}

// MARK: - Selector de Modo de Personalidad
struct PersonalityModeSelector: View {
    @Binding var currentMode: PersonalityMode
    let onSelect: (PersonalityMode) -> Void
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            List(PersonalityMode.allCases) { mode in
                Button {
                    onSelect(mode)
                } label: {
                    HStack(spacing: 16) {
                        Text(mode.icon)
                            .font(.system(size: 40))
                            .frame(width: 60, height: 60)
                            .background(
                                Circle()
                                    .fill(currentMode == mode ? Color.blue.opacity(0.2) : Color.gray.opacity(0.1))
                            )
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text(mode.rawValue)
                                .font(.headline)
                                .foregroundColor(.primary)
                            
                            Text(mode.description)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .lineLimit(2)
                        }
                        
                        Spacer()
                        
                        if currentMode == mode {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.blue)
                                .font(.title2)
                        }
                    }
                    .padding(.vertical, 8)
                }
            }
            .listStyle(.plain)                     // <- Clave: evita estilos agrupados que ocultan contenido
            .navigationTitle("Elegir Personalidad")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cerrar") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Selector de Proveedor de IA
struct AIProviderSelector: View {
    @Binding var currentProvider: AIProvider
    let apiKeyManager: APIKeyManager
    let onSelect: (AIProvider) -> Void
    let onOpenSettings: () -> Void
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            List {
                ForEach(AIProvider.allCases) { provider in
                    Button {
                        if provider.requiresAPIKey && !apiKeyManager.hasAPIKey(for: provider) {
                            onOpenSettings()
                        } else {
                            onSelect(provider)
                        }
                    } label: {
                        HStack(spacing: 16) {
                            Image(systemName: provider.icon)
                                .font(.system(size: 30))
                                .frame(width: 50, height: 50)
                                .background(
                                    Circle()
                                        .fill(currentProvider == provider ? Color.purple.opacity(0.2) : Color.gray.opacity(0.1))
                                )
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text(provider.rawValue)
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                
                                Text(provider.description)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .lineLimit(2)
                                
                                if provider.requiresAPIKey {
                                    HStack(spacing: 4) {
                                        Image(systemName: apiKeyManager.hasAPIKey(for: provider) ? "checkmark.circle.fill" : "key.fill")
                                            .font(.caption)
                                        Text(apiKeyManager.hasAPIKey(for: provider) ? "Configurado" : "Requiere API Key")
                                            .font(.caption2)
                                    }
                                    .foregroundColor(apiKeyManager.hasAPIKey(for: provider) ? .green : .orange)
                                }
                            }
                            
                            Spacer()
                            
                            if currentProvider == provider {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.purple)
                                    .font(.title2)
                            }
                        }
                        .padding(.vertical, 8)
                    }
                }
            }
            .navigationTitle("Proveedor de IA")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cerrar") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        onOpenSettings()
                    } label: {
                        Image(systemName: "gearshape")
                    }
                }
            }
        }
        // presentationDetents se maneja en el .sheet que la muestra
    }
}

// MARK: - Vista de Configuración de API Keys
struct APIKeySettingsView: View {
    @ObservedObject var apiKeyManager: APIKeyManager
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL // multiplataforma para abrir URLs
    
    @State private var showingClaudeInfo = false
    @State private var showingDeepSeekInfo = false
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        Image(systemName: "brain.head.profile")
                            .foregroundColor(.purple)
                        VStack(alignment: .leading) {
                            Text("Claude (Anthropic)")
                                .font(.headline)
                            Text("Claude 3.5 Sonnet")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Button {
                            showingClaudeInfo = true
                        } label: {
                            Image(systemName: "info.circle")
                                .foregroundColor(.blue)
                        }
                    }
                    
                    SecureField("API Key de Claude", text: $apiKeyManager.claudeAPIKey)
                        .textContentType(.password)
                        .autocorrectionDisabled()
                        #if os(iOS)
                        .textInputAutocapitalization(.never)
                        #endif
                } header: {
                    Text("Claude API")
                } footer: {
                    Text("Obtén tu API key en console.anthropic.com")
                }
                
                Section {
                    HStack {
                        Image(systemName: "sparkles")
                            .foregroundColor(.blue)
                        VStack(alignment: .leading) {
                            Text("DeepSeek")
                                .font(.headline)
                            Text("DeepSeek R1")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Button {
                            showingDeepSeekInfo = true
                        } label: {
                            Image(systemName: "info.circle")
                                .foregroundColor(.blue)
                        }
                    }
                    
                    SecureField("API Key de DeepSeek", text: $apiKeyManager.deepseekAPIKey)
                        .textContentType(.password)
                        .autocorrectionDisabled()
                        #if os(iOS)
                        .textInputAutocapitalization(.never)
                        #endif
                } header: {
                    Text("DeepSeek API")
                } footer: {
                    Text("Obtén tu API key en platform.deepseek.com")
                }
                
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Privacidad", systemImage: "lock.shield")
                            .font(.headline)
                        Text("Las API keys se guardan de forma segura en tu dispositivo y solo se usan para comunicarse con los servicios seleccionados.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("Configuración de API")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Listo") {
                        dismiss()
                    }
                }
            }
            .alert("Cómo obtener Claude API Key", isPresented: $showingClaudeInfo) {
                Button("Abrir Console") { openClaudeConsole() }
                Button("Cerrar", role: .cancel) {}
            } message: {
                Text("1. Visita console.anthropic.com\n2. Crea una cuenta o inicia sesión\n3. Ve a 'API Keys'\n4. Crea una nueva API key\n5. Cópiala y pégala aquí")
            }
            .alert("Cómo obtener DeepSeek API Key", isPresented: $showingDeepSeekInfo) {
                Button("Abrir Platform") { openDeepSeekPlatform() }
                Button("Cerrar", role: .cancel) {}
            } message: {
                Text("1. Visita platform.deepseek.com\n2. Crea una cuenta o inicia sesión\n3. Ve a 'API Keys'\n4. Crea una nueva API key\n5. Cópiala y pégala aquí")
            }
        }
    }
    
    private func openClaudeConsole() {
        if let url = URL(string: "https://console.anthropic.com") {
            openURL(url) // funciona en iOS, macOS, etc.
        }
    }
    
    private func openDeepSeekPlatform() {
        if let url = URL(string: "https://platform.deepseek.com") {
            openURL(url)
        }
    }
}

// MARK: - Preview (solo iOS, para macOS se puede quitar o adaptar)
#if os(iOS)
#Preview {
    ChatView()
}

#Preview("Selector de Modos") {
    PersonalityModeSelector(currentMode: .constant(.friendly)) { _ in }
}

#Preview("Selector de Proveedores") {
    AIProviderSelector(
        currentProvider: .constant(.claude),
        apiKeyManager: APIKeyManager(),
        onSelect: { _ in },
        onOpenSettings: {}
    )
}

#Preview("Configuración API") {
    APIKeySettingsView(apiKeyManager: APIKeyManager())
}
#endif
