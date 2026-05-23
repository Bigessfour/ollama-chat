import { ErrorBoundary as ReactErrorBoundary } from 'react-error-boundary'
import { logError } from '../../lib/logger.js'
import { ErrorFallback } from './ErrorFallback.jsx'

export function ErrorBoundary({ children }) {
  return (
    <ReactErrorBoundary
      FallbackComponent={ErrorFallback}
      onError={(error, info) => logError('react.error_boundary', { error, info })}
      onReset={() => window.location.reload()}
    >
      {children}
    </ReactErrorBoundary>
  )
}
