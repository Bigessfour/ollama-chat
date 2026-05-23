import { QueryClient, QueryClientProvider } from '@tanstack/react-query'
import { Toaster } from 'sonner'

const queryClient = new QueryClient({
  defaultOptions: {
    queries: {
      refetchOnWindowFocus: true,
    },
  },
})

export function AppProviders({ children }) {
  return (
    <QueryClientProvider client={queryClient}>
      {children}
      <Toaster
        position="top-center"
        richColors
        closeButton
        toastOptions={{
          classNames: {
            toast:
              'bg-white text-zinc-900 border border-zinc-200 dark:bg-zinc-900 dark:text-zinc-100 dark:border-zinc-700',
          },
        }}
      />
    </QueryClientProvider>
  )
}
