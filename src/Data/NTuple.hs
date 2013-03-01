{-# LANGUAGE FlexibleInstances #-}
{-# LANGUAGE FlexibleContexts #-}
{-# LANGUAGE MultiParamTypeClasses #-}
{-# LANGUAGE UndecidableInstances #-}
{-# LANGUAGE ScopedTypeVariables #-}
{-# LANGUAGE BangPatterns #-}
{-# LANGUAGE TypeOperators #-}
{-# LANGUAGE FunctionalDependencies #-}
{-# LANGUAGE ConstraintKinds #-}

{-# LANGUAGE GADTs #-}
{-# LANGUAGE DataKinds #-}
{-# LANGUAGE KindSignatures #-}
{-# LANGUAGE ExistentialQuantification #-}
{-# LANGUAGE RankNTypes #-}
{-# LANGUAGE GeneralizedNewtypeDeriving #-}
{-# LANGUAGE TypeFamilies #-}

{-# LANGUAGE PolyKinds #-}
{-# LANGUAGE DatatypeContexts #-}

module Data.NTuple'
    where

import Control.Lens
import qualified Data.Vector as V
import qualified Data.Vector.Mutable as VM
import GHC.ST
import GHC.TypeLits
import Unsafe.Coerce
import Debug.Trace

data Color = Red | Blue | Green | Purple
    deriving (Read,Show,Eq,Ord)

data ShowBox = forall a. (Show a) => ShowBox a

instance Show ShowBox where
    show (ShowBox a) = show a

newtype (Show a) => ShowWrap a = ShowWrap a
    deriving (Read,Show,Eq,Ord)

class HMap f hmap hmap2 | f hmap -> hmap2 where
    hmap :: f -> hmap -> hmap2

instance HMap (a->b) (HList '[]) (HList '[]) where
    hmap f HNil = HNil

-- instance HMap (a->b) (HList (x ': xs)) (

-------------------------------------------------------------------------------
-- data types

data HList :: [*] -> * where
  HNil :: HList '[]
  (:::) :: t -> HList ts -> HList (t ': ts)
  
infixr 5 :::

instance Show (HList '[]) where
    show _ = "HNil"
    
instance (Show x, Show (HList xs)) => Show (HList (x ': xs)) where
    show (x:::xs) = show x ++":::"++show xs

class HLength xs where
    hlength :: xs -> Int
    
instance HLength (HList '[]) where
    hlength _ = 0
    
instance (HLength (HList xs)) => HLength (HList (x ': xs)) where
    hlength (x:::xs) = 1+hlength xs

newtype Tuple box xs = Tuple (V.Vector box)

-- tup :: (HLength (HList xs), TupWrite xs x) => (x -> box) -> HList xs -> Tuple box xs
tup boxer xs = Tuple $ V.create $ do
    v <- VM.new n
    tupwrite v (n-1) boxer xs
    return $ v
        where
        n = hlength xs

class TupWrite hlist head box | hlist -> head where
    tupwrite :: VM.MVector s box -> Int -> (head -> box) -> hlist -> ST s () 

instance TupWrite (HList '[]) head box where
    tupwrite v i boxer HNil = return ()
    
instance TupWrite (HList (x ': '[])) x box where
    tupwrite v i boxer (x:::xs) = VM.write v i (boxer x)

class TWrite hlist where
    twrite :: VM.MVector s box -> Int -> (a -> box) -> hlist -> ST s ()
    
instance TWrite (HList '[]) where
    twrite v i boxer HNil = return ()

-- instance TWrite (HList (x ': '[])) where
--     twrite v i boxer (x:::HNil) = VM.write v i (boxer x)



-- instance (TupWrite (HList '[x1]) x1 box) => TupWrite (HList (x0 ': x1 ': '[])) x0 box where
-- instance (TupWrite (HList '[x1]) x1 box) => TupWrite (HList (x0 ': x1 ': '[])) x0 box where
--     tupwrite v i boxer (x:::xs) = VM.write v i (boxer x) >> tupwrite v i boxer xs

-- instance (TupWrite (HList xs) t box) => TupWrite (HList (x ': xs)) x box where
--     tupwrite v i boxer (x:::xs) = VM.write v i (boxer x) -- >> tupwrite v (i-1) (boxer :: t -> box) xs
-- tupwrite :: VM.MVector s box -> Int -> (x -> box) -> HList t1 -> ST s () 
-- tupwrite v i boxer (x:::xs) = VM.write v i undefined -- (boxer x)

--     tupwrite v i boxer (b:::a) = VM.write v i (boxer a) >> tupwrite v (i-1) b

class Boxable xs ys where
    dobox :: xs -> ys
    
instance Boxable (HList '[]) (HList '[]) where
    dobox xs = xs

instance (Show x) => Boxable (HList (x ': xs)) (HList (ShowBox ': xs)) where
    dobox (x:::xs) = (ShowBox x):::xs

-- tup :: (TupWriter xs, TupLen xs) => (x -> box) -> xs -> Tuple box xs
-- tup :: (TupLen xs, TupWriter xs (a->box) box) => (a -> box) -> xs -> Tuple box xs
-- tup boxer xs = Tuple $ V.create $ do
--     v <- VM.new n
--     tupwrite v (n-1) boxer xs
--     return v
--     where
--         n = tuplen xs

-- tup boxer xs = Tuple $ V.create $ do
--     v <- VM.new n
--     tupwrite v (n-1) boxer xs
--     return v
--     where
--         n = hlength xs
--         tupwrite = undefined

instance (Show box) => Show (Tuple box xs) where
    show (Tuple vec) = "(tup $ "++go 0++")"
        where
            go i = if i < V.length vec {--1-}
                then show (vec V.! i) ++ ":::" ++ go (i+1)
                else "HNil"

-------------------------------------------------------------------------------
-- type classes

-- class TupLen t where
--     tuplen :: t -> Int
-- 
-- instance (TupLen b) => TupLen (a ::: b) where
--     tuplen (b ::: a) = 1 + tuplen b
-- 
-- instance TupLen b where
--     tuplen b = 1
-- 
-- class TupWriter xs boxer box {-| xs -> first-} where
--     tupwrite :: VM.MVector s box -> Int -> boxer -> xs -> ST s ()
-- 
-- instance TupWriter x (x->box) box where
--     tupwrite v i boxer xs = VM.write v i (boxer xs)

-- instance (TupWriter b c box) => TupWriter (a:::b) a box where
--     tupwrite v i boxer (b:::a) = VM.write v i (boxer a) >> tupwrite v (i-1) b

-------------------------------------------------------------------------------
-- lens

-- _i :: (SingI n) => Tuple (Replicate n a) -> Int -> a
-- _i (Tuple vec) i = unsafeCoerce $ vec V.! i
-- 
-- data GetIndex xs (n::Nat) a = GetIndex xs

-- getIndex :: xs -> Sing n -> a

{-class TupIndex i n a | i n -> a where
    _i :: (SingI n) => i -> (Sing n) -> a

instance TupIndex (a:::b) Zero b where
    _i (b:::a) sing = b

instance (TupIndex b i c) => TupIndex (a:::b) (Succ i) c where-}
--     _i (b:::a) _ = _i b undefined -- (sing:: Sing i)

-- instance TupIndex (a:::b) 0 b where
--     _i (b:::a) sing = b
-- 
-- instance (TupIndex b (i+1) c, SingI i, SingI (i+1)) => TupIndex (a:::b) i c where
-- --     _i (b:::a) (sing :: Sing i) = _i b (sing:: Sing (i+1))
--     _i (b:::a) _ = _i b (sing:: Sing (i+1))

class Viewable tup where
    view :: (SingI n) => (Sing n) -> (tup a) -> (tup b)



-- class TypeNatIndex {-n-} s t a b | s -> a, t -> b, s b -> t, t a -> s where
--     _i :: {-n -> -}IndexedLens Int s t a b
-- 
-- instance TypeNatIndex {-(Sing 0)-} (a,b) (a',b) a a' where
-- --     _i {-sing-} f tup = undefined -- Tuple (vec V.// [])
-- --     _i {-sing-} f (Tuple vec) = undefined -- Tuple (vec V.// [])

first :: Simple Lens (a,b) a
first f (a,b) = undefined
-------------------------------------------------------------------------------
-- showing
        

-------------------------------------------------------------------------------
-- modification

-- class EmptyTup tup where
--     emptytup :: tup
-- 
-- instance EmptyTup (NTuple' xs) where
--     emptytup = NTuple'
--         { len = 0
--         , getvec = V.replicate n UnsafeBox
--         }
--         where
--             n = 2
-- 
-- class PushBack tup a tup' | tup a -> tup' where
--     pushback :: tup -> a -> tup'
--     
-- instance PushBack (NTuple' xs) a (NTuple' (a ': xs)) where
--     pushback tup a = if n<V.length (getvec tup)
--         then NTuple'
--             { len = (len tup)+1
--             , getvec = runST $ do
--                 v <- V.unsafeThaw $ (getvec tup)
--                 VM.write v (len tup) (unsafeCoerce a)
--                 V.unsafeFreeze v
--             }
--         else NTuple'
--             { len = (len tup)+1
--             , getvec = V.generate ((len tup)*2) $ \i -> if i<(len tup)
--                 then (getvec tup) V.! i
--                 else unsafeCoerce a
--             }
--         where
--             n = len tup
-- 
-- class TupIndexable index where
--     index :: NTuple' xs -> index -> xs :! (ToNat1 (ExtractIndex index))
--     
-- instance (SingI i) => TupIndexable (Index i) where
--     index tup Index = unsafeCoerce (getvec tup V.! i)
--         where
--             i = fromIntegral $ fromSing (sing :: Sing i)

-------------------------------------------------------------------------------
-- type functions

-- data Index (n::Nat) = Index
-- type family ExtractIndex i :: Nat
-- type instance ExtractIndex (Index i) = i

-- class BoxTuple box t t' where
--     boxtuple :: box -> t -> t'

-- instance BoxTuple box (Tuple xs) (V.Vector box) where



type family Map (f :: * -> *) (xs::[*]) :: [*]
type instance Map f '[] = '[]
type instance Map f (x ': xs) = (f x) ': (Map f xs)
-- type instance Box (x:::xs) a = a x:::(Box xs a)

-- type family Replicate (n::Nat) a
-- type instance Replicate n a = Replicate' (ToNat1 n) a
-- type family Replicate' (n::Nat1) a
-- type instance Replicate' (Succ Zero) a = a
-- type instance Replicate' (Succ (Succ xs)) a = a:::(Replicate' (Succ xs) a)

type family Length (xs::[*]) :: Nat
type instance Length '[] = 0
type instance Length (a ': xs) = 1 + (Length xs)

type family MoveR (xs::[*]) (ys::[*]) :: [*]
type instance MoveR '[] ys = ys
type instance MoveR (x ': xs) ys = MoveR xs (x ': ys)

type family Reverse (xs::[*]) :: [*]
type instance Reverse xs = MoveR xs '[]

type family (xs::[*]) ++ (ys::[*]) :: [*]
type instance xs ++ ys = MoveR (Reverse xs) ys

type family (:!) (xs::[a]) (i::Nat1) :: a
type instance (:!) (x ': xs) Zero = x
type instance (:!) (x ': xs) (Succ i) = xs :! i

data Nat1 = Zero | Succ Nat1
type family FromNat1 (n :: Nat1) :: Nat
type instance FromNat1 Zero     = 0
type instance FromNat1 (Succ n) = 1 + FromNat1 n

type family ToNat1 (n :: Nat) :: Nat1
type instance ToNat1 0 = Zero
type instance ToNat1 1 = Succ (ToNat1 0)
type instance ToNat1 2 = Succ (ToNat1 1)
type instance ToNat1 3 = Succ (ToNat1 2)
type instance ToNat1 4 = Succ (ToNat1 3)
type instance ToNat1 5 = Succ (ToNat1 4)
type instance ToNat1 6 = Succ (ToNat1 5)
type instance ToNat1 7 = Succ (ToNat1 6)
type instance ToNat1 8 = Succ (ToNat1 7)
type instance ToNat1 9 = Succ (ToNat1 8)
type instance ToNat1 10 = Succ (ToNat1 9)
type instance ToNat1 11 = Succ (ToNat1 10)
type instance ToNat1 12 = Succ (ToNat1 11)
type instance ToNat1 13 = Succ (ToNat1 12)
type instance ToNat1 14 = Succ (ToNat1 13)
type instance ToNat1 15 = Succ (ToNat1 14)
type instance ToNat1 16 = Succ (ToNat1 15)
type instance ToNat1 17 = Succ (ToNat1 16)
type instance ToNat1 18 = Succ (ToNat1 17)
type instance ToNat1 19 = Succ (ToNat1 18)
type instance ToNat1 20 = Succ (ToNat1 19)