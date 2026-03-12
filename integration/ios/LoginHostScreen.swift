import SwiftUI

final class LoginHostStore {
    func submitLogin() {}
}

struct LoginHostScreen: View {
    @State private var screenState = LoginScreenState()
    private let store = LoginHostStore()

    var body: some View {
        LoginScreen(
            state: $screenState,
            actions: LoginScreenActions(
                submitLogin: { store.submitLogin() }
            )
        )
    }
}
