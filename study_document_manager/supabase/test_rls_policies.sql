-- =====================================================================
-- KỊCH BẢN KIỂM THỬ TỰ ĐỘNG CHÍNH SÁCH BẢO MẬT (RLS) TRÊN SUPABASE
-- File: supabase/test_rls_policies.sql
-- Mục đích: Kiểm thử Checklist 5 & Checklist 6 với ít nhất 3 tài khoản:
--   - Tài khoản 1 (Owner)   : 11111111-1111-1111-1111-111111111111
--   - Tài khoản 2 (Viewer)  : 22222222-2222-2222-2222-222222222222
--   - Tài khoản 3 (Editor)  : 33333333-3333-3333-3333-333333333333
--   - Tài khoản 4 (Stranger): 44444444-4444-4444-4444-444444444444
-- Cách chạy: Dán vào Supabase SQL Editor và bấm Run.
-- =====================================================================

DO $$
DECLARE
  v_owner_id   uuid := '11111111-1111-1111-1111-111111111111'::uuid;
  v_viewer_id  uuid := '22222222-2222-2222-2222-222222222222'::uuid;
  v_editor_id  uuid := '33333333-3333-3333-3333-333333333333'::uuid;
  v_stranger_id uuid := '44444444-4444-4444-4444-444444444444'::uuid;
  v_doc_id     uuid := 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'::uuid;
  v_count      int;
BEGIN
  RAISE NOTICE '=== BẮT ĐẦU KIỂM THỬ ROW LEVEL SECURITY (RLS) TRÊN SUPABASE ===';

  -- 1. TẠO DỮ LIỆU GIẢ LẬP TRONG PROFILES
  INSERT INTO public.profiles (id, email, display_name)
  VALUES 
    (v_owner_id, 'owner@cashew.edu.vn', 'Nguyen Van Owner'),
    (v_viewer_id, 'viewer@cashew.edu.vn', 'Tran Thi Viewer'),
    (v_editor_id, 'editor@cashew.edu.vn', 'Le Van Editor'),
    (v_stranger_id, 'stranger@cashew.edu.vn', 'Pham Van Stranger')
  ON CONFLICT (id) DO UPDATE SET 
    email = EXCLUDED.email,
    display_name = EXCLUDED.display_name;

  -- Xóa dữ liệu test cũ nếu có
  DELETE FROM public.document_permissions WHERE document_id = v_doc_id;
  DELETE FROM public.documents WHERE id = v_doc_id;

  -- 2. TẠO TÀI LIỆU CỦA OWNER VÀ PHÂN QUYỀN
  INSERT INTO public.documents (id, owner_id, title, subject, type, notes, tags)
  VALUES (
    v_doc_id,
    v_owner_id,
    'Tài liệu Kiểm thử Phân quyền RLS',
    'SWE302',
    'reference',
    'Tài liệu này được dùng để xác minh quyền hạn 3 tài khoản.',
    ARRAY['RLS', 'Security', 'Testing']
  );

  -- Cấp quyền Viewer cho User 2 và Editor cho User 3
  INSERT INTO public.document_permissions (document_id, owner_id, shared_with_user_id, role)
  VALUES 
    (v_doc_id, v_owner_id, v_viewer_id, 'viewer'),
    (v_doc_id, v_owner_id, v_editor_id, 'editor');

  RAISE NOTICE '-> Dữ liệu kiểm thử đã sẵn sàng.';
END $$;

-- ---------------------------------------------------------------------
-- TEST CASE 1: KIỂM THỬ TÀI KHOẢN 1 (OWNER)
-- Kì vọng: Xem được, Sửa được, Xóa được, Quản lý quyền được
-- ---------------------------------------------------------------------
SET LOCAL ROLE authenticated;
SET LOCAL request.jwt.claims TO '{"sub": "11111111-1111-1111-1111-111111111111", "role": "authenticated"}';

SELECT id, title, owner_id FROM public.documents WHERE id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa';
-- [KẾT QUẢ MONG ĐỢI]: 1 hàng trả về (Owner xem được)

UPDATE public.documents 
SET title = 'Tài liệu đã được Owner cập nhật' 
WHERE id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa';
-- [KẾT QUẢ MONG ĐỢI]: UPDATE 1 (Owner sửa thành công)

-- ---------------------------------------------------------------------
-- TEST CASE 2: KIỂM THỬ TÀI KHOẢN 2 (VIEWER)
-- Kì vọng: Xem được, KHÔNG được sửa, KHÔNG được xóa
-- ---------------------------------------------------------------------
SET LOCAL ROLE authenticated;
SET LOCAL request.jwt.claims TO '{"sub": "22222222-2222-2222-2222-222222222222", "role": "authenticated"}';

SELECT id, title FROM public.documents WHERE id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa';
-- [KẾT QUẢ MONG ĐỢI]: 1 hàng trả về (Viewer đọc được tài liệu chia sẻ)

UPDATE public.documents 
SET title = 'Viewer cố tình sửa nội dung trái phép' 
WHERE id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa';
-- [KẾT QUẢ MONG ĐỢI]: UPDATE 0 (RLS chặn cập nhật của Viewer!)

DELETE FROM public.documents 
WHERE id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa';
-- [KẾT QUẢ MONG ĐỢI]: DELETE 0 (RLS chặn xóa của Viewer!)

-- ---------------------------------------------------------------------
-- TEST CASE 3: KIỂM THỬ TÀI KHOẢN 3 (EDITOR)
-- Kì vọng: Xem được, SỬA ĐƯỢC, KHÔNG được xóa
-- ---------------------------------------------------------------------
SET LOCAL ROLE authenticated;
SET LOCAL request.jwt.claims TO '{"sub": "33333333-3333-3333-3333-333333333333", "role": "authenticated"}';

SELECT id, title FROM public.documents WHERE id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa';
-- [KẾT QUẢ MONG ĐỢI]: 1 hàng trả về (Editor đọc được)

UPDATE public.documents 
SET title = 'Tài liệu đã được Editor chỉnh sửa hợp lệ' 
WHERE id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa';
-- [KẾT QUẢ MONG ĐỢI]: UPDATE 1 (Editor sửa thành công!)

DELETE FROM public.documents 
WHERE id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa';
-- [KẾT QUẢ MONG ĐỢI]: DELETE 0 (RLS chặn thao tác DELETE của Editor!)

-- ---------------------------------------------------------------------
-- TEST CASE 4: KIỂM THỬ TÀI KHOẢN 4 (STRANGER - NGƯỜI LẠ KHÔNG ĐƯỢC CHIA SẺ)
-- Kì vọng: Hoàn toàn KHÔNG nhìn thấy, KHÔNG sửa, KHÔNG xóa
-- ---------------------------------------------------------------------
SET LOCAL ROLE authenticated;
SET LOCAL request.jwt.claims TO '{"sub": "44444444-4444-4444-4444-444444444444", "role": "authenticated"}';

SELECT * FROM public.documents WHERE id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa';
-- [KẾT QUẢ MONG ĐỢI]: 0 hàng trả về (RLS ẩn hoàn toàn tài liệu đối với người lạ)

UPDATE public.documents 
SET title = 'Người lạ cố tình sửa' 
WHERE id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa';
-- [KẾT QUẢ MONG ĐỢI]: UPDATE 0

DELETE FROM public.documents 
WHERE id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa';
-- [KẾT QUẢ MONG ĐỢI]: DELETE 0

-- ---------------------------------------------------------------------
-- TEST CASE 5: THU HỒI QUYỀN (REVOKE SHARE) VÀ XÁC MINH LẠI
-- ---------------------------------------------------------------------
SET LOCAL ROLE authenticated;
SET LOCAL request.jwt.claims TO '{"sub": "11111111-1111-1111-1111-111111111111", "role": "authenticated"}';

-- Owner thu hồi quyền của Viewer (User 2)
DELETE FROM public.document_permissions 
WHERE document_id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa' 
  AND shared_with_user_id = '22222222-2222-2222-2222-222222222222';
-- [KẾT QUẢ MONG ĐỢI]: DELETE 1

-- Kiểm tra lại quyền của User 2
SET LOCAL ROLE authenticated;
SET LOCAL request.jwt.claims TO '{"sub": "22222222-2222-2222-2222-222222222222", "role": "authenticated"}';

SELECT * FROM public.documents WHERE id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa';
-- [KẾT QUẢ MONG ĐỢI]: 0 hàng trả về (User 2 không còn quyền xem tài liệu nữa)

RESET ROLE;
