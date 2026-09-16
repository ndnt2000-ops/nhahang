-- ============================================================
-- 🗄️ SUPABASE SCHEMA - KenRestaurant Production Database
-- Phiên bản: 3.0 — Chuẩn hóa ID, bảo mật RLS & Realtime
-- ============================================================

-- ── 1. BẢNG NGƯỜI DÙNG (users) ─────────────────────────────
CREATE TABLE IF NOT EXISTS public.users (
  id            TEXT PRIMARY KEY DEFAULT gen_random_uuid()::text,
  name          TEXT NOT NULL,
  email         TEXT UNIQUE NOT NULL,
  password_hash TEXT,
  phone         TEXT,
  address       TEXT,
  role          TEXT NOT NULL DEFAULT 'client' CHECK (role IN ('admin', 'client')),
  avatar        TEXT,
  verified      BOOLEAN DEFAULT TRUE,
  last_login_at TIMESTAMPTZ,
  created_at    TIMESTAMPTZ DEFAULT NOW()
);

-- ── 2. BẢNG ĐẶT BÀN (reservations) ────────────────────────
-- Chuyển id sang TEXT để tương thích cả ID tự sinh từ frontend (res-...) và UUID
CREATE TABLE IF NOT EXISTS public.reservations (
  id            TEXT PRIMARY KEY DEFAULT gen_random_uuid()::text,
  user_id       TEXT REFERENCES public.users(id) ON DELETE SET NULL,
  customer_name TEXT NOT NULL,
  email         TEXT,
  phone         TEXT NOT NULL,
  guests        INTEGER NOT NULL DEFAULT 2,
  date          TEXT NOT NULL,
  time          TEXT NOT NULL,
  table_type    TEXT,
  notes         TEXT,
  status        TEXT DEFAULT 'pending' CHECK (status IN ('pending', 'confirmed', 'cancelled', 'completed')),
  created_at    TIMESTAMPTZ DEFAULT NOW()
);

-- ── 3. BẢNG PHIÊN NGỒI BÀN (table_sessions) ─────────────────
CREATE TABLE IF NOT EXISTS public.table_sessions (
  id             TEXT PRIMARY KEY DEFAULT gen_random_uuid()::text,
  user_id        TEXT REFERENCES public.users(id) ON DELETE SET NULL,
  customer_name  TEXT,
  customer_phone TEXT,
  table_code     TEXT NOT NULL,
  table_name     TEXT NOT NULL,
  table_area     TEXT,
  table_floor    TEXT,
  session_type   TEXT DEFAULT 'scan' CHECK (session_type IN ('scan', 'manual', 'url_param', 'layout_click')),
  created_at     TIMESTAMPTZ DEFAULT NOW()
);

-- ── 4. BẢNG ĐƠN HÀNG (orders) ──────────────────────────────
CREATE TABLE IF NOT EXISTS public.orders (
  id               TEXT PRIMARY KEY,
  user_id          TEXT REFERENCES public.users(id) ON DELETE SET NULL,
  customer_name    TEXT,
  customer_phone   TEXT,
  customer_address TEXT,
  customer_email   TEXT,
  payment_method   TEXT DEFAULT 'cod',
  notes            TEXT,
  delivery_type    TEXT DEFAULT 'now' CHECK (delivery_type IN ('now', 'scheduled', 'dine_in')),
  scheduled_time   TEXT,
  subtotal         NUMERIC(12,2) DEFAULT 0,
  delivery_fee     NUMERIC(12,2) DEFAULT 0,
  discount         NUMERIC(12,2) DEFAULT 0,
  tax              NUMERIC(12,2) DEFAULT 0,
  total            NUMERIC(12,2) DEFAULT 0,
  voucher_code     TEXT,
  status           TEXT DEFAULT 'confirmed' CHECK (status IN ('confirmed', 'preparing', 'shipping', 'delivered', 'cancelled')),
  estimated_time   TEXT,
  driver           JSONB,
  order_type       TEXT DEFAULT 'delivery',
  table_number     TEXT,
  table_area       TEXT,
  created_at       TIMESTAMPTZ DEFAULT NOW()
);

-- ── 5. BẢNG CHI TIẾT ĐƠN HÀNG (order_items) ────────────────
CREATE TABLE IF NOT EXISTS public.order_items (
  id                TEXT PRIMARY KEY DEFAULT gen_random_uuid()::text,
  order_id          TEXT REFERENCES public.orders(id) ON DELETE CASCADE,
  food_id           TEXT,
  food_name         TEXT,
  quantity          INTEGER DEFAULT 1,
  unit_price        NUMERIC(12,2) DEFAULT 0,
  total_price       NUMERIC(12,2) DEFAULT 0,
  selected_size     TEXT,
  selected_toppings JSONB DEFAULT '[]'
);

-- ── 6. BẢNG ĐÁNH GIÁ (reviews) ─────────────────────────────
CREATE TABLE IF NOT EXISTS public.reviews (
  id           TEXT PRIMARY KEY DEFAULT gen_random_uuid()::text,
  user_id      TEXT REFERENCES public.users(id) ON DELETE SET NULL,
  user_name    TEXT NOT NULL,
  user_email   TEXT,
  user_phone   TEXT,
  user_avatar  TEXT,
  rating       NUMERIC(2,1) NOT NULL DEFAULT 5,
  comment      TEXT NOT NULL,
  dish_name    TEXT,
  food_id      TEXT,
  photos       JSONB DEFAULT '[]',
  verified     BOOLEAN DEFAULT TRUE,
  likes        INTEGER DEFAULT 0,
  created_at   TIMESTAMPTZ DEFAULT NOW()
);

-- ── 7. BẬT ROW LEVEL SECURITY (RLS) ────────────────────────
ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.reservations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.table_sessions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.orders ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.order_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.reviews ENABLE ROW LEVEL SECURITY;

-- ── 8. CHÍNH SÁCH BẢO MẬT (RLS POLICIES) ───────────────────
-- Cho phép khách đăng ký & đọc tài khoản cơ bản
DROP POLICY IF EXISTS "allow_insert_users" ON public.users;
CREATE POLICY "allow_insert_users" ON public.users FOR INSERT TO anon, authenticated WITH CHECK (true);

DROP POLICY IF EXISTS "allow_select_users" ON public.users;
CREATE POLICY "allow_select_users" ON public.users FOR SELECT TO anon, authenticated USING (true);

DROP POLICY IF EXISTS "allow_update_users" ON public.users;
CREATE POLICY "allow_update_users" ON public.users FOR UPDATE TO anon, authenticated USING (true);

-- Đặt bàn: Khách gửi yêu cầu, admin xem danh sách
DROP POLICY IF EXISTS "allow_insert_reservations" ON public.reservations;
CREATE POLICY "allow_insert_reservations" ON public.reservations FOR INSERT TO anon, authenticated WITH CHECK (true);

DROP POLICY IF EXISTS "allow_select_reservations" ON public.reservations;
CREATE POLICY "allow_select_reservations" ON public.reservations FOR SELECT TO anon, authenticated USING (true);

DROP POLICY IF EXISTS "allow_update_reservations" ON public.reservations;
CREATE POLICY "allow_update_reservations" ON public.reservations FOR UPDATE TO anon, authenticated USING (true);

-- Đơn hàng & Chi tiết món
DROP POLICY IF EXISTS "allow_insert_orders" ON public.orders;
CREATE POLICY "allow_insert_orders" ON public.orders FOR INSERT TO anon, authenticated WITH CHECK (true);

DROP POLICY IF EXISTS "allow_select_orders" ON public.orders;
CREATE POLICY "allow_select_orders" ON public.orders FOR SELECT TO anon, authenticated USING (true);

DROP POLICY IF EXISTS "allow_update_orders" ON public.orders;
CREATE POLICY "allow_update_orders" ON public.orders FOR UPDATE TO anon, authenticated USING (true);

DROP POLICY IF EXISTS "allow_insert_order_items" ON public.order_items;
CREATE POLICY "allow_insert_order_items" ON public.order_items FOR INSERT TO anon, authenticated WITH CHECK (true);

DROP POLICY IF EXISTS "allow_select_order_items" ON public.order_items;
CREATE POLICY "allow_select_order_items" ON public.order_items FOR SELECT TO anon, authenticated USING (true);

-- Đánh giá công khai
DROP POLICY IF EXISTS "allow_insert_reviews" ON public.reviews;
CREATE POLICY "allow_insert_reviews" ON public.reviews FOR INSERT TO anon, authenticated WITH CHECK (true);

DROP POLICY IF EXISTS "allow_select_reviews" ON public.reviews;
CREATE POLICY "allow_select_reviews" ON public.reviews FOR SELECT TO anon, authenticated USING (true);

-- Bàn ăn
DROP POLICY IF EXISTS "allow_insert_table_sessions" ON public.table_sessions;
CREATE POLICY "allow_insert_table_sessions" ON public.table_sessions FOR INSERT TO anon, authenticated WITH CHECK (true);

DROP POLICY IF EXISTS "allow_select_table_sessions" ON public.table_sessions;
CREATE POLICY "allow_select_table_sessions" ON public.table_sessions FOR SELECT TO anon, authenticated USING (true);

-- ── 9. REALTIME PUBLICATION ────────────────────────────────
-- Cho phép Supabase Realtime phát sự kiện cho bảng orders và reservations
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables 
    WHERE pubname = 'supabase_realtime' AND tablename = 'orders'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.orders;
  END IF;
  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables 
    WHERE pubname = 'supabase_realtime' AND tablename = 'reservations'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.reservations;
  END IF;
END $$;
