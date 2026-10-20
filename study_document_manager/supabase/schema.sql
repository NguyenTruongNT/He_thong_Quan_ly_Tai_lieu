-- =====================================================================
-- HỆ THỐNG QUẢN LÝ TÀI LIỆU HỌC TẬP (FLUTTER + FIREBASE + SUPABASE)
-- File: supabase/schema.sql
-- Đề tài: TH2 - Phát triển Hệ thống Quản lý Tài liệu Đa nền tảng
-- Tác giả: Nguyễn Văn Trường (Nhóm trưởng - Core Architect & QA)
-- Mô tả: DDL khởi tạo và nâng cấp cơ sở dữ liệu quan hệ trên Supabase Cloud:
--   1. Bảng profiles (Hồ sơ người dùng & Tag sở thích)
--   2. Bảng documents (Tài liệu học tập + Bản đồ Tọa độ + Vị trí vật lý)
--   3. Bảng document_permissions (Chia sẻ quyền viewer/editor)
--   4. Bảng borrow_requests (Nghiệp vụ Mượn / Trả tài liệu học tập)
--   5. Row Level Security (RLS) bảo vệ từng bảng độc lập theo auth.uid()
--   6. Kích hoạt Supabase Realtime cho bảng borrow_requests
--   7. Stored Procedures (RPCs) tối ưu hóa luồng mượn/trả và chia sẻ
--   8. Cấu hình Supabase Storage bucket ('documents') & RLS phân quyền tệp
-- Hướng dẫn áp dụng:
--   1. Mở Supabase Dashboard (https://supabase.com/dashboard)
--   2. Chọn Project của bạn -> Điều hướng đến "SQL Editor"
--   3. Tạo New Query, dán toàn bộ nội dung file này và nhấn "Run".
-- =====================================================================

-- ---------------------------------------------------------------------
-- 1. BẢNG NGƯỜI DÙNG (PROFILES)
-- ---------------------------------------------------------------------
create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  email text,
  display_name text,
  avatar_url text,
  favorite_tags text[] not null default '{}',
  created_at timestamptz not null default now()
);

-- Nâng cấp nếu bảng profiles đã tồn tại từ trước (thêm favorite_tags)
alter table public.profiles
  add column if not exists favorite_tags text[] not null default '{}';

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

  -- Bổ sung trường TH2: Vị trí vật lý & Tọa độ bản đồ
  latitude double precision,        -- Vĩ độ (vd: 21.0074)
  longitude double precision,       -- Kinh độ (vd: 105.8247)
  location_name text,               -- Tên vị trí lưu trữ: "Tủ B3, Thư viện Tạ Quang Bửu"
  is_physical boolean not null default false, -- true: Sách/bản in vật lý; false: File số

  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- Nâng cấp nếu bảng documents đã tồn tại từ TH1
alter table public.documents
  add column if not exists latitude double precision,
  add column if not exists longitude double precision,
  add column if not exists location_name text,
  add column if not exists is_physical boolean not null default false;

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

-- ---------------------------------------------------------------------
-- 4. BẢNG YÊU CẦU MƯỢN / TRẢ TÀI LIỆU (BORROW_REQUESTS) - MỚI CHO TH2
-- ---------------------------------------------------------------------
create table if not exists public.borrow_requests (
  id uuid primary key default gen_random_uuid(),
  document_id uuid not null references public.documents(id) on delete cascade,
  borrower_id uuid not null references public.profiles(id) on delete cascade,
  borrower_email text not null default '',
  owner_id uuid not null references public.profiles(id) on delete cascade,
  status text not null check (status in ('pending', 'approved', 'rejected', 'returned')) default 'pending',
  request_date timestamptz not null default now(),
  due_date timestamptz,
  return_date timestamptz,
  note text not null default '',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (borrower_id <> owner_id)
);

-- ---------------------------------------------------------------------
-- 5. CHỈ MỤC TỐI ƯU TRUY VẤN (INDEXES)
-- ---------------------------------------------------------------------
create index if not exists idx_documents_owner_id
  on public.documents(owner_id);
create index if not exists idx_documents_subject
  on public.documents(subject);
create index if not exists idx_documents_is_physical
  on public.documents(is_physical);
create index if not exists idx_documents_tags
  on public.documents using gin (tags);

create index if not exists idx_document_permissions_recipient
  on public.document_permissions(shared_with_user_id);
create index if not exists idx_document_permissions_doc
  on public.document_permissions(document_id);

create index if not exists idx_borrow_requests_borrower
  on public.borrow_requests(borrower_id);
create index if not exists idx_borrow_requests_owner
  on public.borrow_requests(owner_id);
create index if not exists idx_borrow_requests_doc
  on public.borrow_requests(document_id);
create index if not exists idx_borrow_requests_status
  on public.borrow_requests(status);

-- ---------------------------------------------------------------------
-- 6. TRIGGER TỰ ĐỘNG ĐỒNG BỘ PROFILE KHI CÓ USER MỚI TRONG AUTH
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

-- Trigger tự động cập nhật timestamp updated_at cho borrow_requests
create or replace function public.update_borrow_request_timestamp()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists trg_borrow_requests_updated_at on public.borrow_requests;
create trigger trg_borrow_requests_updated_at
  before update on public.borrow_requests
  for each row execute function public.update_borrow_request_timestamp();

-- ---------------------------------------------------------------------
-- 7. ROW LEVEL SECURITY (RLS) - BẢO MẬT VÀ PHÂN QUYỀN
-- ---------------------------------------------------------------------
alter table public.profiles enable row level security;
alter table public.documents enable row level security;
alter table public.document_permissions enable row level security;
alter table public.borrow_requests enable row level security;

-- --- RLS CHO BẢNG PROFILES ---
drop policy if exists profiles_select_all on public.profiles;
create policy profiles_select_all on public.profiles
  for select to authenticated
  using (true);

drop policy if exists profiles_update_self on public.profiles;
create policy profiles_update_self on public.profiles
  for update to authenticated
  using (id = (select auth.uid()))
  with check (id = (select auth.uid()));

-- --- RLS CHO BẢNG DOCUMENTS ---
-- 1. Quyền Xem: Chủ sở hữu HOẶC Người được cấp quyền HOẶC Người đang mượn tài liệu
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
    or exists (
      select 1 from public.borrow_requests b
      where b.document_id = documents.id
        and b.borrower_id = (select auth.uid())
        and b.status in ('pending', 'approved')
    )
  );

-- 2. Quyền Thêm mới: Chỉ chủ sở hữu tạo tài liệu của mình
drop policy if exists documents_insert_owner on public.documents;
create policy documents_insert_owner on public.documents
  for insert to authenticated
  with check (owner_id = (select auth.uid()));

-- 3. Quyền Chỉnh sửa: Chủ sở hữu HOẶC Người có quyền 'editor'
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

-- 4. Quyền Xóa: Chỉ chủ sở hữu
drop policy if exists documents_delete_owner on public.documents;
create policy documents_delete_owner on public.documents
  for delete to authenticated
  using (owner_id = (select auth.uid()));

-- --- RLS CHO BẢNG DOCUMENT_PERMISSIONS ---
drop policy if exists permissions_select_owner_or_recipient on public.document_permissions;
create policy permissions_select_owner_or_recipient on public.document_permissions
  for select to authenticated
  using (
    owner_id = (select auth.uid())
    or shared_with_user_id = (select auth.uid())
  );

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

drop policy if exists permissions_delete_owner on public.document_permissions;
create policy permissions_delete_owner on public.document_permissions
  for delete to authenticated
  using (owner_id = (select auth.uid()));

-- --- RLS CHO BẢNG BORROW_REQUESTS (MỚI CHO TH2) ---
-- 1. Xem yêu cầu: Người mượn (borrower) HOẶC Chủ sở hữu (owner)
drop policy if exists borrow_requests_select on public.borrow_requests;
create policy borrow_requests_select on public.borrow_requests
  for select to authenticated
  using (
    borrower_id = (select auth.uid())
    or owner_id = (select auth.uid())
  );

-- 2. Tạo yêu cầu mượn: Chỉ người mượn tự tạo cho mình (không mượn của chính mình)
drop policy if exists borrow_requests_insert on public.borrow_requests;
create policy borrow_requests_insert on public.borrow_requests
  for insert to authenticated
  with check (
    borrower_id = (select auth.uid())
    and owner_id <> (select auth.uid())
  );

-- 3. Cập nhật yêu cầu: Chủ sở hữu duyệt/từ chối/báo hoàn trả; Người mượn báo đã trả hoặc cập nhật ghi chú
drop policy if exists borrow_requests_update on public.borrow_requests;
create policy borrow_requests_update on public.borrow_requests
  for update to authenticated
  using (
    borrower_id = (select auth.uid())
    or owner_id = (select auth.uid())
  )
  with check (
    borrower_id = (select auth.uid())
    or owner_id = (select auth.uid())
  );

-- 4. Xóa yêu cầu: Người mượn có thể hủy yêu cầu khi còn ở trạng thái pending
drop policy if exists borrow_requests_delete on public.borrow_requests;
create policy borrow_requests_delete on public.borrow_requests
  for delete to authenticated
  using (
    borrower_id = (select auth.uid())
    and status = 'pending'
  );

-- ---------------------------------------------------------------------
-- 8. KÍCH HOẠT SUPABASE REALTIME CHO BORROW_REQUESTS
-- ---------------------------------------------------------------------
-- Cho phép client Flutter lắng nghe luồng sự kiện Realtime khi có yêu cầu mượn mới
do $$
begin
  if exists (
    select 1 from pg_publication where pubname = 'supabase_realtime'
  ) then
    alter publication supabase_realtime add table public.borrow_requests;
  end if;
exception
  when duplicate_object then null;
end $$;

-- ---------------------------------------------------------------------
-- 9. STORED PROCEDURES HỖ TRỢ NGHIỆP VỤ MƯỢN / TRẢ & CHIA SẺ
-- ---------------------------------------------------------------------

-- Hàm: Gửi yêu cầu mượn tài liệu (Tự tra cứu owner_id và borrower_email)
create or replace function public.create_borrow_request(
  p_document_id uuid,
  p_due_date timestamptz default null,
  p_note text default ''
)
returns json
language plpgsql
security definer
set search_path = public
as $$
declare
  v_owner_id uuid;
  v_borrower_email text;
  v_borrower_name text;
  v_doc_title text;
  v_new_id uuid;
begin
  -- Lấy thông tin tài liệu
  select owner_id, title into v_owner_id, v_doc_title
  from public.documents
  where id = p_document_id;

  if v_owner_id is null then
    raise exception 'Tài liệu không tồn tại.';
  end if;

  if v_owner_id = auth.uid() then
    raise exception 'Bạn không thể gửi yêu cầu mượn tài liệu của chính mình.';
  end if;

  -- Lấy thông tin người mượn hiện tại
  select email, display_name into v_borrower_email, v_borrower_name
  from public.profiles
  where id = auth.uid();

  -- Thêm bản ghi mượn
  insert into public.borrow_requests (
    document_id,
    borrower_id,
    borrower_email,
    owner_id,
    status,
    request_date,
    due_date,
    note
  ) values (
    p_document_id,
    auth.uid(),
    coalesce(v_borrower_email, ''),
    v_owner_id,
    'pending',
    now(),
    p_due_date,
    p_note
  )
  returning id into v_new_id;

  return json_build_object(
    'success', true,
    'request_id', v_new_id,
    'document_id', p_document_id,
    'document_title', v_doc_title,
    'status', 'pending'
  );
end;
$$;

-- Hàm: Chủ sở hữu duyệt hoặc từ chối yêu cầu mượn
create or replace function public.respond_borrow_request(
  p_request_id uuid,
  p_action text -- 'approved' hoặc 'rejected'
)
returns json
language plpgsql
security definer
set search_path = public
as $$
declare
  v_owner_id uuid;
  v_status text;
begin
  if p_action not in ('approved', 'rejected') then
    raise exception 'Hành động không hợp lệ (chỉ chấp nhận approved hoặc rejected).';
  end if;

  select owner_id into v_owner_id
  from public.borrow_requests
  where id = p_request_id;

  if v_owner_id is null then
    raise exception 'Yêu cầu mượn không tồn tại.';
  end if;

  if v_owner_id <> auth.uid() then
    raise exception 'Chỉ chủ sở hữu tài liệu mới có quyền duyệt yêu cầu này.';
  end if;

  update public.borrow_requests
  set status = p_action,
      updated_at = now()
  where id = p_request_id;

  return json_build_object(
    'success', true,
    'request_id', p_request_id,
    'new_status', p_action
  );
end;
$$;

-- Hàm: Đánh dấu đã hoàn trả tài liệu
create or replace function public.mark_document_returned(
  p_request_id uuid
)
returns json
language plpgsql
security definer
set search_path = public
as $$
declare
  v_borrower_id uuid;
  v_owner_id uuid;
begin
  select borrower_id, owner_id into v_borrower_id, v_owner_id
  from public.borrow_requests
  where id = p_request_id;

  if v_borrower_id is null then
    raise exception 'Yêu cầu mượn không tồn tại.';
  end if;

  if auth.uid() not in (v_borrower_id, v_owner_id) then
    raise exception 'Bạn không có quyền cập nhật trạng thái trả cho tài liệu này.';
  end if;

  update public.borrow_requests
  set status = 'returned',
      return_date = now(),
      updated_at = now()
  where id = p_request_id;

  return json_build_object(
    'success', true,
    'request_id', p_request_id,
    'status', 'returned'
  );
end;
$$;

-- Phân quyền thực thi stored procedures
grant execute on function public.create_borrow_request to authenticated;
grant execute on function public.respond_borrow_request to authenticated;
grant execute on function public.mark_document_returned to authenticated;

-- Chia sẻ tài liệu theo Email
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
  select owner_id into v_owner_id
  from public.documents
  where id = p_document_id;

  if v_owner_id is null then
    raise exception 'Tài liệu không tồn tại.';
  end if;

  if v_owner_id <> auth.uid() then
    raise exception 'Chỉ chủ sở hữu mới có quyền chia sẻ tài liệu này.';
  end if;

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
-- 10. CẤU TRÚC LƯU TRỮ VÀ RLS CHO SUPABASE STORAGE (BUCKET 'documents')
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

-- Quyền Tải tệp về: Chủ sở hữu HOẶC Người được chia sẻ HOẶC Người đang mượn tài liệu
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
          or exists (
            select 1 from public.borrow_requests b
            where b.document_id = d.id
              and b.borrower_id = (select auth.uid())
              and b.status = 'approved'
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
