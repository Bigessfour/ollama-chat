import { useQuery } from '@tanstack/react-query'
import { getHealth, getReadyAllowNotReady } from '../api/client.js'
import { queryKeys } from '../api/queries.js'

export function useHealthQuery() {
  return useQuery({
    queryKey: queryKeys.health,
    queryFn: getHealth,
    refetchInterval: 30_000,
    retry: 2,
    staleTime: 10_000,
  })
}

export function useReadyQuery(enabled = true) {
  return useQuery({
    queryKey: queryKeys.ready,
    queryFn: getReadyAllowNotReady,
    enabled,
    refetchInterval: (query) => {
      const ready = query.state.data?.ok === true
      return ready ? 30_000 : 10_000
    },
    retry: 3,
    staleTime: 5_000,
  })
}

export function useBackendStatus() {
  const healthQuery = useHealthQuery()
  const readyQuery = useReadyQuery(healthQuery.isSuccess)

  const isLoading = healthQuery.isLoading || readyQuery.isLoading
  const healthOk = healthQuery.isSuccess
  const readyOk = readyQuery.data?.ok === true

  let status = 'offline'
  if (healthOk && readyOk) status = 'online'
  else if (healthOk && !readyOk) status = 'degraded'

  const model =
    readyQuery.data?.data?.model ??
    healthQuery.data?.model ??
    'gemma:2b'

  return {
    status,
    isLoading,
    isOnline: status === 'online',
    model,
    healthQuery,
    readyQuery,
    refetch: () => {
      healthQuery.refetch()
      readyQuery.refetch()
    },
  }
}
