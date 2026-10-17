-- =====================================================================
-- HỆ THỐNG QUẢN LÝ TÀI LIỆU HỌC TẬP (FLUTTER + FIREBASE + SUPABASE)
-- File: supabase/schema.sql
-- Mô tả: DDL khởi tạo cơ sở dữ liệu quan hệ trên Supabase:
--   1. Bảng profiles (Người dùng) - đồng bộ tự động từ auth.users
--   2. Bảng documents (Tài liệu) - lưu metadata, liên kết file Cloud
--   3. Bảng document_permissions (Quyền chia sẻ) - phân quyền viewer/editor
--   4. Row Level Security (RLS) bảo vệ từng bảng
--   5. Bucket và chính sách cho Supabase Storage (documents bucket)
--   6. Stored Procedures hỗ trợ chia sẻ tiện lợi qua Email
-- Hướng dẫn: Mở Supabase Dashboard > SQL Editor > Dán toàn bộ script và nhấn Run.
-- =====================================================================

-- ---------------------------------------------------------------------
-- 1. BẢNG NGƯỜI DÙNG (PROFILES)
-- ---------------------------------------------------------------------
create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  email text,
  display_name text,
  avatar_url text,
  created_at timestamptz not null default now()
);

-- ---------------------------------------------------------------------
-- 2. BẢNG TÀI LIỆU HỌC TẬP (DOCUMENTS)
-- ---------------------------------------------------------------------
create table if not exists public.documents (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references public.profiles(id) on delete cascade,
  title text not null check (char_length(trim(title)) between 3 and 250),
  subject text not null default '',
  type text not null check (type in ('lecture', 'assignment', 'reference', 'exam')),
  notes text not null default '',
  tags text[] not null default '{}',
  file_path text,            -- Đường dẫn storage (Firebase Storage hoặc Supabase Storage)
  file_url text,             -- URL tải về hoặc link tài liệu bên ngoài
  checksum text,             -- Mã băm toàn vẹn tệp (SHA-256)
  checksum_algo text not null default 'sha256',
  version integer not null default 1,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- ---------------------------------------------------------------------
-- 3. BẢNG QUYỀN CHIA SẺ TÀI LIỆU (DOCUMENT_PERMISSIONS)
-- ---------------------------------------------------------------------
create table if not exists public.document_permissions (
  document_id uuid not null references public.documents(id) on delete cascade,
  owner_id uuid not null references public.profiles(id) on delete cascade,
  shared_with_user_id uuid not null references public.profiles(id) on delete cascade,
  role text not null check (role in ('viewer', 'editor')),
  created_at timestamptz not null default now(),
  primary key (document_id, shared_with_user_id),
  check (owner_id <> shared_with_user_id)
);

-- Chỉ mục tối ưu hóa hiệu năng truy vấn
create index if not exists idx_documents_owner_id
  on public.documents(owner_id);
create index if not exists idx_documents_subject
  on public.documents(subject);
create index if not exists idx_document_permissions_recipient
  on public.document_permissions(shared_with_user_id);
create index if not exists idx_document_permissions_doc
  on public.document_permissions(document_id);

-- ---------------------------------------------------------------------
-- 4. TRIGGER TỰ ĐỘNG ĐỒNG BỘ PROFILE KHI CÓ USER MỚI TRONG AUTH
-- ---------------------------------------------------------------------
create or replace function public.create_profile_for_new_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.profiles (id, email, display_name, avatar_url)
  values (
    new.id,
    new.email,
    coalesce(new.raw_user_meta_data ->> 'full_name', new.raw_user_meta_data ->> 'name', split_part(new.email, '@', 1)),
    new.raw_user_meta_data ->> 'avatar_url'
  )
  on conflict (id) do update
    set email = excluded.email,
        display_name = coalesce(excluded.display_name, public.profiles.display_name),
        avatar_url = coalesce(excluded.avatar_url, public.profiles.avatar_url);
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert or update of email, raw_user_meta_data on auth.users
  for each row execute function public.create_profile_for_new_user();

-- ---------------------------------------------------------------------
-- 5. ROW LEVEL SECURITY (RLS) - BẢO MẬT VÀ PHÂN QUYỀN
-- ---------------------------------------------------------------------
alter table public.profiles enable row level security;
alter table public.documents enable row level security;
alter table public.document_permissions enable row level security;

-- --- RLS CHO BẢNG PROFILES ---
-- Cho phép mọi user đã đăng nhập xem profile người khác để hỗ trợ tìm kiếm & chia sẻ
drop policy if exists profiles_select_all on public.profiles;
drop policy if exists profiles_select_self on public.profiles;
create policy profiles_select_all on public.profiles
  for select to authenticated
  using (true);

-- Chỉ user sở hữu mới có quyền cập nhật profile của mình
drop policy if exists profiles_update_self on public.profiles;
create policy profiles_update_self on public.profiles
  for update to authenticated
  using (id = (select auth.uid()))
  with check (id = (select auth.uid()));

-- --- RLS CHO BẢNG DOCUMENTS ---
-- 1. Quyền Xem (SELECT): Chủ sở hữu HOẶC Người được chia sẻ (viewer/editor)
drop policy if exists documents_select_owner_or_shared on public.documents;
create policy documents_select_owner_or_shared on public.documents
  for select to authenticated
  using (
    owner_id = (select auth.uid())
    or exists (
      select 1 from public.document_permissions p
      where p.document_id = documents.id
        and p.owner_id = documents.owner_id
        and p.shared_with_user_id = (select auth.uid())
    )
  );

-- 2. Quyền Thêm mới (INSERT): Chỉ chủ sở hữu tạo tài liệu của chính mình
drop policy if exists documents_insert_owner on public.documents;
create policy documents_insert_owner on public.documents
  for insert to authenticated
  with check (owner_id = (select auth.uid()));

-- 3. Quyền Chỉnh sửa (UPDATE): Chủ sở hữu HOẶC Người có quyền 'editor'
-- Người có quyền 'viewer' BỊ TỪ CHỐI không thể cập nhật!
drop policy if exists documents_update_owner_or_editor on public.documents;
create policy documents_update_owner_or_editor on public.documents
  for update to authenticated
  using (
    owner_id = (select auth.uid())
    or exists (
      select 1 from public.document_permissions p
      where p.document_id = documents.id
        and p.owner_id = documents.owner_id
        and p.shared_with_user_id = (select auth.uid())
        and p.role = 'editor'
    )
  )
  with check (
    owner_id = (select auth.uid())
    or exists (
      select 1 from public.document_permissions p
      where p.document_id = documents.id
        and p.owner_id = documents.owner_id
        and p.shared_with_user_id = (select auth.uid())
        and p.role = 'editor'
    )
  );

-- 4. Quyền Xóa (DELETE): CHỈ DUY NHẤT chủ sở hữu mới có quyền xóa tài liệu
-- Editor và Viewer KHÔNG ĐƯỢC PHÉP xóa
drop policy if exists documents_delete_owner on public.documents;
create policy documents_delete_owner on public.documents
  for delete to authenticated
  using (owner_id = (select auth.uid()));

-- --- RLS CHO BẢNG DOCUMENT_PERMISSIONS ---
-- 1. Xem quyền: Chủ sở hữu hoặc người được cấp quyền
drop policy if exists permissions_select_owner_or_recipient on public.document_permissions;
create policy permissions_select_owner_or_recipient on public.document_permissions
  for select to authenticated
  using (
    owner_id = (select auth.uid())
    or shared_with_user_id = (select auth.uid())
  );

-- 2. Cấp quyền mới (INSERT): CHỈ chủ sở hữu tài liệu
drop policy if exists permissions_insert_owner on public.document_permissions;
create policy permissions_insert_owner on public.document_permissions
  for insert to authenticated
  with check (
    owner_id = (select auth.uid())
    and exists (
      select 1 from public.documents d
      where d.id = document_id and d.owner_id = (select auth.uid())
    )
  );

-- 3. Cập nhật quyền (UPDATE): CHỈ chủ sở hữu tài liệu
drop policy if exists permissions_update_owner on public.document_permissions;
create policy permissions_update_owner on public.document_permissions
  for update to authenticated
  using (owner_id = (select auth.uid()))
  with check (
    owner_id = (select auth.uid())
    and exists (
      select 1 from public.documents d
      where d.id = document_id and d.owner_id = (select auth.uid())
    )
  );

-- 4. Thu hồi quyền (DELETE): CHỈ chủ sở hữu tài liệu
drop policy if exists permissions_delete_owner on public.document_permissions;
create policy permissions_delete_owner on public.document_permissions
  for delete to authenticated
  using (owner_id = (select auth.uid()));

-- ---------------------------------------------------------------------
-- 6. STORED PROCEDURES HỖ TRỢ CHIA SẺ TIỆN LỢI QUA EMAIL
-- ---------------------------------------------------------------------

-- Hàm 1: Chia sẻ tài liệu bằng Email người nhận (tiện lợi, không cần UUID)
create or replace function public.share_document_by_email(
  p_document_id uuid,
  p_email text,
  p_role text
)
returns json
language plpgsql
security definer
set search_path = public
as $$
declare
  v_owner_id uuid;
  v_target_user_id uuid;
  v_target_name text;
begin
  -- Kiểm tra quyền sở hữu tài liệu
  select owner_id into v_owner_id
  from public.documents
  where id = p_document_id;

  if v_owner_id is null then
    raise exception 'Tài liệu không tồn tại.';
  end if;

  if v_owner_id <> auth.uid() then
    raise exception 'Chỉ chủ sở hữu mới có quyền chia sẻ tài liệu này.';
  end if;

  -- Tìm user nhận theo email
  select id, display_name into v_target_user_id, v_target_name
  from public.profiles
  where lower(trim(email)) = lower(trim(p_email));

  if v_target_user_id is null then
    raise exception 'Không tìm thấy người dùng có email: %', p_email;
  end if;

  if v_target_user_id = auth.uid() then
    raise exception 'Không thể chia sẻ tài liệu cho chính mình.';
  end if;

  if p_role not in ('viewer', 'editor') then
    raise exception 'Quyền không hợp lệ (chỉ chấp nhận viewer hoặc editor).';
  end if;

  insert into public.document_permissions (document_id, owner_id, shared_with_user_id, role, created_at)
  values (p_document_id, v_owner_id, v_target_user_id, p_role, now())
  on conflict (document_id, shared_with_user_id)
  do update set role = excluded.role, created_at = now();

  return json_build_object(
    'success', true,
    'document_id', p_document_id,
    'shared_with_user_id', v_target_user_id,
    'recipient_name', v_target_name,
    'recipient_email', p_email,
    'role', p_role
  );
end;
$$;

-- Hàm 2: Thu hồi quyền chia sẻ tài liệu theo Email hoặc User ID
create or replace function public.revoke_document_share_by_email(
  p_document_id uuid,
  p_email text
)
returns json
language plpgsql
security definer
set search_path = public
as $$
declare
  v_owner_id uuid;
  v_target_user_id uuid;
begin
  select owner_id into v_owner_id
  from public.documents
  where id = p_document_id;

  if v_owner_id is null then
    raise exception 'Tài liệu không tồn tại.';
  end if;

  if v_owner_id <> auth.uid() then
    raise exception 'Chỉ chủ sở hữu mới có quyền thu hồi chia sẻ.';
  end if;

  select id into v_target_user_id
  from public.profiles
  where lower(trim(email)) = lower(trim(p_email));

  if v_target_user_id is null then
    raise exception 'Không tìm thấy người dùng có email: %', p_email;
  end if;

  delete from public.document_permissions
  where document_id = p_document_id and shared_with_user_id = v_target_user_id;

  return json_build_object('success', true);
end;
$$;

grant execute on function public.share_document_by_email to authenticated;
grant execute on function public.revoke_document_share_by_email to authenticated;

-- ---------------------------------------------------------------------
-- 7. CẤU TRÚC LƯU TRỮ VÀ RLS CHO SUPABASE STORAGE (BUCKET 'documents')
-- (Phương án lưu trữ tệp Cloud hoàn toàn miễn phí 100% không cần thẻ)
-- ---------------------------------------------------------------------
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'documents',
  'documents',
  false,
  20971520, -- 20 MiB
  array[
    'application/pdf',
    'application/msword',
    'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
    'application/vnd.ms-powerpoint',
    'application/vnd.openxmlformats-officedocument.presentationml.presentation',
    'application/vnd.ms-excel',
    'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    'text/plain'
  ]
)
on conflict (id) do update
  set public = false,
      file_size_limit = excluded.file_size_limit,
      allowed_mime_types = excluded.allowed_mime_types;

-- Quyền Tải tệp lên: Chỉ Owner tài liệu
drop policy if exists document_files_insert_owner on storage.objects;
create policy document_files_insert_owner on storage.objects
  for insert to authenticated
  with check (
    bucket_id = 'documents'
    and (storage.foldername(name))[1] = 'users'
    and (storage.foldername(name))[2] = (select auth.uid())::text
    and (storage.foldername(name))[3] = 'documents'
    and exists (
      select 1 from public.documents d
      where d.id = ((storage.foldername(name))[4])::uuid
        and d.owner_id = (select auth.uid())
    )
  );

-- Quyền Tải tệp về: Chủ sở hữu HOẶC Người được chia sẻ (viewer/editor)
drop policy if exists document_files_select_owner_or_shared on storage.objects;
create policy document_files_select_owner_or_shared on storage.objects
  for select to authenticated
  using (
    bucket_id = 'documents'
    and exists (
      select 1 from public.documents d
      where d.id = ((storage.foldername(name))[4])::uuid
        and (
          d.owner_id = (select auth.uid())
          or exists (
            select 1 from public.document_permissions p
            where p.document_id = d.id
              and p.owner_id = d.owner_id
              and p.shared_with_user_id = (select auth.uid())
          )
        )
    )
  );

-- Quyền Cập nhật file: Chỉ chủ sở hữu
drop policy if exists document_files_update_owner on storage.objects;
create policy document_files_update_owner on storage.objects
  for update to authenticated
  using (
    bucket_id = 'documents'
    and (storage.foldername(name))[2] = (select auth.uid())::text
    and exists (
      select 1 from public.documents d
      where d.id = ((storage.foldername(name))[4])::uuid
        and d.owner_id = (select auth.uid())
    )
  )
  with check (
    bucket_id = 'documents'
    and (storage.foldername(name))[2] = (select auth.uid())::text
    and exists (
      select 1 from public.documents d
      where d.id = ((storage.foldername(name))[4])::uuid
        and d.owner_id = (select auth.uid())
    )
  );

-- Quyền Xóa file: Chỉ chủ sở hữu
drop policy if exists document_files_delete_owner on storage.objects;
create policy document_files_delete_owner on storage.objects
  for delete to authenticated
  using (
    bucket_id = 'documents'
    and exists (
      select 1 from public.documents d
      where d.id = ((storage.foldername(name))[4])::uuid
        and d.owner_id = (select auth.uid())
    )
  );
