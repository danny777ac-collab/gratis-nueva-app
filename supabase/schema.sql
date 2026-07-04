-- =====================================================================
-- Esquema Supabase para "Gracia" (migración desde Firebase/Firestore)
-- Ejecuta este script en el SQL Editor de tu proyecto Supabase.
-- Crea las tablas, políticas RLS, buckets de Storage y habilita Realtime.
-- Los nombres de columnas se conservan iguales a los campos de Firestore
-- (algunos en camelCase, por eso van entre comillas dobles).
-- =====================================================================

-- ---------------------------------------------------------------------
-- Extensiones
-- ---------------------------------------------------------------------
create extension if not exists "pgcrypto";

-- ---------------------------------------------------------------------
-- Tabla: usuarios  (antes colección "usuarios", doc id = uid del auth)
-- ---------------------------------------------------------------------
create table if not exists public.usuarios (
  id uuid primary key references auth.users (id) on delete cascade,
  uid text,
  nombre text,
  email text,
  telefono text,
  fecha_registro timestamptz default now(),
  privacidad boolean default true,
  descripcion_bio text,
  "fotoPerfilUrl" text,
  s_entregadas integer default 0,
  s_recibidas integer default 0,
  s_reputacion boolean default true,
  nombre_mesias_personalizado text,
  donaciones_entregadas integer default 0,
  donaciones_recibidas integer default 0
);

-- ---------------------------------------------------------------------
-- Tablas: donaciones y necesidades (antes colecciones del "muro")
-- ---------------------------------------------------------------------
create table if not exists public.donaciones (
  id uuid primary key default gen_random_uuid(),
  "usuarioId" text,
  "usuarioNombre" text,
  "usuarioTelefono" text,
  "duenoId" text,
  "autorNombre" text,
  "autorFoto" text,
  titulo text,
  descripcion text,
  ubicacion text,
  categoria text,
  "imagenesUrls" jsonb default '[]'::jsonb,
  postulantes jsonb default '[]'::jsonb,
  fecha timestamptz default now(),
  "expiraEn" timestamptz,
  transaccion_activa boolean default false,
  "receptorId" text,
  "receptorNombre" text,
  confirmado_por_emisor boolean default false,
  confirmado_por_receptor boolean default false,
  "transaccionConfirmadaEmisor" boolean default false,
  "transaccionConfirmadaReceptor" boolean default false,
  "receptorConfirmadoId" text default ''
);

create table if not exists public.necesidades (
  id uuid primary key default gen_random_uuid(),
  "usuarioId" text,
  "usuarioNombre" text,
  "usuarioTelefono" text,
  "duenoId" text,
  "autorNombre" text,
  "autorFoto" text,
  titulo text,
  descripcion text,
  ubicacion text,
  categoria text,
  "imagenesUrls" jsonb default '[]'::jsonb,
  postulantes jsonb default '[]'::jsonb,
  fecha timestamptz default now(),
  "expiraEn" timestamptz,
  transaccion_activa boolean default false,
  "receptorId" text,
  "receptorNombre" text,
  confirmado_por_emisor boolean default false,
  confirmado_por_receptor boolean default false,
  "transaccionConfirmadaEmisor" boolean default false,
  "transaccionConfirmadaReceptor" boolean default false,
  "receptorConfirmadoId" text default ''
);

-- ---------------------------------------------------------------------
-- Tabla: postulantes (antes subcolección donaciones/{id}/postulantes)
-- ---------------------------------------------------------------------
create table if not exists public.postulantes (
  id uuid primary key default gen_random_uuid(),
  post_id uuid not null,
  coleccion text not null,
  uid text,
  nombre text,
  telefono text,
  fecha timestamptz default now()
);
create index if not exists postulantes_post_idx on public.postulantes (post_id, coleccion);

-- ---------------------------------------------------------------------
-- Tabla: comentarios (antes subcolección usuarios/{uid}/comentarios)
-- ---------------------------------------------------------------------
create table if not exists public.comentarios (
  id uuid primary key default gen_random_uuid(),
  usuario_id text not null,
  autor text,
  texto text,
  fecha timestamptz default now()
);
create index if not exists comentarios_usuario_idx on public.comentarios (usuario_id);

-- ---------------------------------------------------------------------
-- Tabla: historial (antes colección "historial")
-- ---------------------------------------------------------------------
create table if not exists public.historial (
  id uuid primary key default gen_random_uuid(),
  item text,
  descripcion text,
  categoria text,
  tipo text,
  "emisorId" text,
  "emisorNombre" text,
  "receptorId" text,
  "receptorNombre" text,
  "tituloActividad" text,
  fecha text,
  fecha_completado timestamptz default now()
);

-- ---------------------------------------------------------------------
-- Tabla: reportes (antes colección "reportes")
-- ---------------------------------------------------------------------
create table if not exists public.reportes (
  id uuid primary key default gen_random_uuid(),
  "postId" text,
  motivo text,
  "reportadorId" text,
  fecha timestamptz default now(),
  estado text default 'pendiente'
);

-- =====================================================================
-- Row Level Security
-- =====================================================================
alter table public.usuarios     enable row level security;
alter table public.donaciones   enable row level security;
alter table public.necesidades  enable row level security;
alter table public.postulantes  enable row level security;
alter table public.comentarios  enable row level security;
alter table public.historial    enable row level security;
alter table public.reportes     enable row level security;

-- usuarios: lectura pública (perfiles), cada quien crea/edita su propia fila
drop policy if exists usuarios_select on public.usuarios;
create policy usuarios_select on public.usuarios for select using (true);

drop policy if exists usuarios_insert on public.usuarios;
create policy usuarios_insert on public.usuarios for insert with check (auth.uid() = id);

drop policy if exists usuarios_update on public.usuarios;
create policy usuarios_update on public.usuarios for update using (auth.uid() = id) with check (auth.uid() = id);

-- Helper macro-ish: para las tablas operativas permitimos a usuarios
-- autenticados leer/crear/editar/borrar (necesario para el flujo de
-- confirmación mutua donde el receptor edita el post de otro usuario).
-- La lectura es pública para poder mostrar el muro.

do $$
declare t text;
begin
  foreach t in array array['donaciones','necesidades','postulantes','comentarios','historial','reportes']
  loop
    execute format('drop policy if exists %I_select on public.%I;', t, t);
    execute format('create policy %I_select on public.%I for select using (true);', t, t);

    execute format('drop policy if exists %I_insert on public.%I;', t, t);
    execute format('create policy %I_insert on public.%I for insert with check (auth.uid() is not null);', t, t);

    execute format('drop policy if exists %I_update on public.%I;', t, t);
    execute format('create policy %I_update on public.%I for update using (auth.uid() is not null) with check (auth.uid() is not null);', t, t);

    execute format('drop policy if exists %I_delete on public.%I;', t, t);
    execute format('create policy %I_delete on public.%I for delete using (auth.uid() is not null);', t, t);
  end loop;
end $$;

-- =====================================================================
-- Realtime (equivalente a los .snapshots() de Firestore)
-- =====================================================================
do $$
declare t text;
begin
  foreach t in array array['usuarios','donaciones','necesidades','postulantes','comentarios','historial','reportes']
  loop
    begin
      execute format('alter publication supabase_realtime add table public.%I;', t);
    exception when duplicate_object then
      null;
    end;
  end loop;
end $$;

-- =====================================================================
-- Storage buckets (antes Firebase Storage)
--   perfiles      -> fotos de perfil (perfiles/{uid}.jpg)
--   publicaciones -> imágenes de posts (publicaciones/{postId}/imagen_{i}.jpg)
-- =====================================================================
insert into storage.buckets (id, name, public)
values ('perfiles', 'perfiles', true)
on conflict (id) do update set public = true;

insert into storage.buckets (id, name, public)
values ('publicaciones', 'publicaciones', true)
on conflict (id) do update set public = true;

-- Lectura pública de ambos buckets; escritura solo autenticados.
drop policy if exists "storage_public_read" on storage.objects;
create policy "storage_public_read" on storage.objects
  for select using (bucket_id in ('perfiles', 'publicaciones'));

drop policy if exists "storage_auth_insert" on storage.objects;
create policy "storage_auth_insert" on storage.objects
  for insert with check (bucket_id in ('perfiles', 'publicaciones') and auth.uid() is not null);

drop policy if exists "storage_auth_update" on storage.objects;
create policy "storage_auth_update" on storage.objects
  for update using (bucket_id in ('perfiles', 'publicaciones') and auth.uid() is not null);

drop policy if exists "storage_auth_delete" on storage.objects;
create policy "storage_auth_delete" on storage.objects
  for delete using (bucket_id in ('perfiles', 'publicaciones') and auth.uid() is not null);
