import SwiftUI

struct LoginView: View {
    @StateObject private var viewModel = LoginViewModel()
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                Spacer()
                
                // Icône Placeholder (On remplacera par le logo de Beeper)
                Image(systemName: "message.fill")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 80, height: 80)
                    .foregroundColor(.blue)
                    .padding(.bottom, 20)
                
                Text("Bienvenue sur BeeperLite")
                    .font(.title2)
                    .fontWeight(.bold)
                
                VStack(spacing: 16) {
                    TextField("Nom d'utilisateur Matrix", text: $viewModel.username)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                    
                    SecureField("Mot de passe", text: $viewModel.password)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                }
                .padding(.horizontal, 32)
                
                // Affichage des erreurs
                if let errorMessage = viewModel.errorMessage {
                    Text(errorMessage)
                        .foregroundColor(.red)
                        .font(.footnote)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }
                
                // Bouton de connexion avec loader asynchrone
                Button(action: {
                    Task {
                        await viewModel.login()
                    }
                }) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.blue)
                            .frame(height: 50)
                            .padding(.horizontal, 32)
                        
                        if viewModel.isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        } else {
                            Text("Se connecter")
                                .foregroundColor(.white)
                                .fontWeight(.semibold)
                        }
                    }
                }
                .disabled(viewModel.isLoading)
                
                Spacer()
                Spacer()
            }
            .navigationBarHidden(true)
            .background(Color(UIColor.systemBackground).edgesIgnoringSafeArea(.all))
        }
        // Style iOS 15 pour éviter que la NavigationView n'affiche un double écran sur iPad
        .navigationViewStyle(StackNavigationViewStyle())
    }
}

struct LoginView_Previews: PreviewProvider {
    static var previews: some View {
        LoginView()
    }
}
