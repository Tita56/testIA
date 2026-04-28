# Chat con IA - Multi-Proveedor

Una aplicación de chat iOS que soporta múltiples proveedores de IA con modos de personalidad intercambiables.

## 🚀 Características

### Proveedores de IA Soportados

1. **Apple Intelligence** (iOS 18.1+, iPhone 15 Pro+, Mac con Apple Silicon)
   - ✅ Privacidad total (procesamiento on-device)
   - ✅ No requiere API key
   - ✅ Gratis
   - ❌ Solo dispositivos compatibles

2. **Claude** (Anthropic)
   - ✅ Claude 3.5 Sonnet
   - ✅ Funciona en cualquier iPhone
   - ✅ Respuestas de alta calidad
   - ⚠️ Requiere API key

3. **DeepSeek**
   - ✅ DeepSeek R1
   - ✅ Funciona en cualquier iPhone
   - ✅ Open source
   - ⚠️ Requiere API key

### Modos de Personalidad

- 😊 **Amigable** - Conversación casual
- 👨‍🏫 **Profesor** - Explicaciones educativas
- 👨‍💻 **Programador** - Enfocado en código Swift
- ✍️ **Poeta** - Respuestas creativas
- 💼 **Profesional** - Tono formal
- 🏴‍☠️ **Pirata** - Divertido y aventurero
- 💪 **Motivador** - Inspirador

## 📋 Requisitos

- **iOS 15.0+** para proveedores externos (Claude, DeepSeek)
- **iOS 18.1+** para Apple Intelligence
- **iPhone 15 Pro/Pro Max+** o **Mac con Apple Silicon** para Apple Intelligence

## 🔑 Configuración de API Keys

### Claude (Anthropic)

1. Visita [console.anthropic.com](https://console.anthropic.com)
2. Crea una cuenta o inicia sesión
3. Ve a "API Keys"
4. Crea una nueva API key
5. Cópiala y pégala en la configuración de la app

**Costo**: ~$3 USD por millón de tokens de entrada, ~$15 por millón de salida

### DeepSeek

1. Visita [platform.deepseek.com](https://platform.deepseek.com)
2. Crea una cuenta o inicia sesión
3. Ve a "API Keys"
4. Crea una nueva API key
5. Cópiala y pégala en la configuración de la app

**Costo**: Más económico que Claude (consultar precios actuales)

## 🎮 Comandos Disponibles

Escribe estos comandos en el chat:

```
/ayuda          - Muestra todos los comandos
/borrar         - Limpia la conversación
/nueva          - Reinicia la sesión
/modo           - Abre el selector de personalidad
/modo [nombre]  - Cambia directo a un modo
```

### Ejemplos:

```
/modo poeta
/modo pirata
/modo programador
```

## 📱 Uso

### Cambiar Proveedor de IA

1. Toca el botón del proveedor (arriba a la izquierda)
2. Selecciona el proveedor deseado
3. Si requiere API key, configúrala tocando el ícono de configuración

### Cambiar Modo de Personalidad

1. Toca el botón del modo (arriba a la derecha)
2. Selecciona la personalidad deseada
3. O usa el comando `/modo [nombre]`

### Enviar Mensajes

- Escribe tu mensaje en el campo de texto
- Toca el botón de enviar (flecha azul)
- Las respuestas aparecen en tiempo real (streaming)

## 🏗️ Arquitectura

```
ChatView.swift          - Vista principal del chat
AIService.swift         - Servicios de IA (Claude, DeepSeek)
PersonalityMode         - Definición de personalidades
AIProvider             - Gestión de proveedores
APIKeyManager          - Almacenamiento seguro de keys
```

## 🔒 Privacidad y Seguridad

- Las API keys se almacenan localmente en UserDefaults
- Para producción, considera usar Keychain
- Apple Intelligence procesa todo on-device (máxima privacidad)
- Claude y DeepSeek requieren conexión a internet

## 🛠️ Mejoras Futuras

- [ ] Guardar conversaciones
- [ ] Exportar chats
- [ ] Más proveedores (Gemini, etc.)
- [ ] Personalización avanzada de parámetros
- [ ] Soporte para imágenes
- [ ] Mensajes de voz
- [ ] Almacenamiento en Keychain

## 📄 Licencia

Este código es de ejemplo educativo. Úsalo libremente.

## 🤝 Contribuciones

¡Siéntete libre de mejorar y extender esta app!
