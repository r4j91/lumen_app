# Camada de dados — Stacked

Contrato atual e caminho de migração para Riverpod + go_router.

## Repositórios

| Repositório | Responsabilidade |
|-------------|------------------|
| `TaskRepository` | SELECT unificado (`kTaskSelect`), listas por contexto (hoje, inbox, projeto, filtros), mutações comuns |
| `ProjectRepository` | CRUD de projetos, favoritos, stats para home/filtros |
| `SubtaskRepository` | Persistência parcial de subtarefas (`persistSubtask`) |
| `LabelRepository` / `SectionRepository` | Metadados de etiquetas e seções |

**Regra:** telas não duplicam strings `select(...)` de tasks — usam `TaskRepository` ou `kTaskSelect` exportado.

Persistência pontual ainda aceitável em sheets (`TaskDetailPersistence`), mas novas queries de lista devem ir ao repositório.

## TaskSync (estado atual)

`TaskSync` é um **barramento de invalidação**, não um store:

- Cada tela mantém **cópia local** da lista (`List<Task>` no `State`).
- Após mutação (delete, save, subtarefa), chama `TaskSync.instance.notifyChanged()`.
- Listeners registrados em `initState` recarregam do Supabase (`_loadTasks()`).
- Debounce de **180 ms** agrupa rajadas (ex.: fechar sheet + sync labels).

### Limitações

- Sem single source of truth — abas podem divergir por ~180 ms ou se uma tela esquecer o listener.
- Reload completo por aba (N queries) em cada mudança.
- `IndexedStack` mantém todas as tabs vivas; listeners acumulam.

## Migração futura (Riverpod)

Quando adicionar Riverpod:

1. **Providers async** por domínio: `todayTasksProvider`, `inboxTasksProvider`, `projectsProvider`.
2. **Substituir TaskSync** por `ref.invalidate(...)` ou updates otimistas no notifier.
3. **Manter repositórios** como camada fina sobre Supabase — providers chamam repos, não `supabase.from` direto.
4. **go_router** substitui `IndexedStack` + `GlobalKey` de refresh; deep links passam a funcionar.

Ordem sugerida: providers de leitura (today/inbox) → mutations com invalidate → remover TaskSync quando zero listeners.

## Notificações

`TaskRepository.deleteProject` e `ProjectRepository.deleteProject` disparam `TaskSync.notifyChanged()` porque tarefas do projeto somem junto.

Mutations que **não** disparam sync hoje (ex.: autosave silencioso no task detail) dependem do callback `onSaved` do sheet ou reload ao voltar à lista.
