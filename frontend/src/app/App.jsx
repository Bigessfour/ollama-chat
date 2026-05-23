import { ErrorBoundary } from '../components/errors/ErrorBoundary.jsx'
import { ChatPage } from '../components/chat/ChatPage.jsx'
import { AppProviders } from './providers.jsx'

export default function App() {
  return (
    <AppProviders>
      <ErrorBoundary>
        <ChatPage />
      </ErrorBoundary>
    </AppProviders>
  )
}
