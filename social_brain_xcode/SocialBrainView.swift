import SwiftUI

struct SocialBrainView: View {
    @State private var inputText = ""
    @State private var messages = SocialBrainMessage.mockMessages
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                ScrollView {
                    VStack(spacing: 20) {
                        // Header
                        Text("社交大脑")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal)
                            .padding(.top)
                        
                        // Message bubbles
                        ForEach(messages) { message in
                            MessageBubble(text: message.content, isFromUser: message.isFromUser)
                        }
                    }
                    .padding(.bottom, 80)
                }
                
                // Input bar
                HStack {
                    TextField("", text: $inputText)
                        .padding(12)
                        .background(Color(.systemGray6))
                        .cornerRadius(25)
                    
                    Button(action: {
                        // Send message action
                    }) {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.system(size: 30))
                            .foregroundColor(.blue)
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 10)
                .background(Color(.systemBackground))
                .shadow(color: Color.black.opacity(0.1), radius: 2, y: -1)
            }
            .navigationBarHidden(true)
        }
    }
}

struct MessageBubble: View {
    let text: String
    let isFromUser: Bool
    
    var body: some View {
        HStack {
            if isFromUser {
                Spacer()
            }
            
            Text(text)
                .padding(16)
                .background(isFromUser ? Color.blue : Color(.systemGray6))
                .foregroundColor(isFromUser ? .white : .primary)
                .cornerRadius(20)
                .padding(.horizontal)
            
            if !isFromUser {
                Spacer()
            }
        }
    }
}

struct SocialBrainView_Previews: PreviewProvider {
    static var previews: some View {
        SocialBrainView()
    }
} 