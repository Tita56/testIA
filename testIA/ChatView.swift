import SwiftUI
import FoundationModels

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

// MARK: - Vista Principal del Chat
struct ChatView: View {
    @State private var messages: [ChatMessage] = []
    @State private var inputText = ""
    @State private var isGenerating = false
    @State private var streamingResponse = ""
    
    // Referencia al modelo de lenguaje del sistema
    private let model = SystemLanguageModel.default
    
    // Sesión del modelo con instrucciones
    @State private var session: LanguageModelSession?
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Verificar disponibilidad del modelo
                switch model.availability {
                case .available:
                    chatContent
                case .unavailable(.deviceNotEligible):
                    unavailableView(message: "Este dispositivo no es compatible con Apple Intelligence")
                case .unavailable(.appleIntelligenceNotEnabled):
                    unavailableView(message: "Por favor, activa Apple Intelligence en Ajustes")
                case .unavailable(.modelNotReady):
                    unavailableView(message: "El modelo se está descargando...")
                case .unavailable(let other):
                    unavailableView(message: "Modelo no disponible: \(other)")
                }
            }
            .navigationTitle("Chat con IA")
            .navigationBarTitleDisplayMode(.inline)
        }
        .onAppear {
            setupSession()
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
        .background(Color(.systemBackground))
    }
    
    // MARK: - Vista de No Disponible
    private func unavailableView(message: String) -> some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 60))
                .foregroundStyle(.orange)
            
            Text(message)
                .font(.headline)
                .multilineTextAlignment(.center)
                .padding()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Computed Properties
    private var canSend: Bool {
        !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    // MARK: - Funciones
    private func setupSession() {
        let instructions = """
        Eres un asistente amigable y útil.
        Responde de manera clara y concisa.
        Si no sabes algo, admítelo honestamente.
        Mantén un tono conversacional y amable.
        """
        
        session = LanguageModelSession(instructions: instructions)
    }
    
    private func sendMessage() {
        guard canSend, let session = session else { return }
        
        let userMessage = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        inputText = ""
        
        // Agregar mensaje del usuario
        messages.append(ChatMessage(content: userMessage, isUser: true))
        
        // Generar respuesta
        Task {
            isGenerating = true
            streamingResponse = ""
            
            do {
                // Usar streaming para obtener la respuesta
                let stream = session.streamResponse(to: userMessage)
                
                var fullResponse = ""
                for try await partial in stream {
                    streamingResponse = partial.content ?? ""
                    fullResponse = partial.content ?? ""
                }
                
                // Agregar respuesta completa
                if !fullResponse.isEmpty {
                    messages.append(ChatMessage(content: fullResponse, isUser: false))
                }
                
                streamingResponse = ""
            } catch {
                // Manejar errores
                let errorMessage = "Lo siento, ocurrió un error: \(error.localizedDescription)"
                messages.append(ChatMessage(content: errorMessage, isUser: false))
            }
            
            isGenerating = false
        }
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
                    .background(message.isUser ? Color.blue : Color(.systemGray5))
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
}

// MARK: - Preview
#Preview {
    ChatView()
}
