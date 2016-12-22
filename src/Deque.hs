module Deque (
  Deque,
  deque,
  mdeque,
  push,
  pop,
  popWhile,
  runFold,
  size,
) where

import Data.Foldable

-- A double ended queue which keeps track of a front and a back, as well as
-- an accumulation function. Inspired by https://people.cs.uct.ac.za/~ksmith/articles/sliding_window_minimum.html#sliding-window-minimum-algorithm
--
-- It uses Okasaki's two-stack implementation. The core idea is two maintain
-- a front and a back stack. At any point, each stack contains all its
-- elements as well as the partial accumulations up to that point. For
-- instance, if the accumulation function is (+), the stack might look like
-- [3,2,1] -> [(3,6), (2,3), (1,1)]
-- Holding all the partial sums alongside the elements of the stack.
-- That makes a perfectly good stack with partial sums, but how do we get a
-- FIFO queue with rolling sums?
-- The trick is two maintain two stacks, one is the front with elements
-- 'on the way in', and the other is the back with elements 'on the way out'.
-- That way, we have partial sums for both stacks and to calculate
-- the partial (or 'rolling') sum for the whole deque we just add the
-- top partial sums together.
-- Consider the list [1,2,3,4,2,1] (which is currently split in the middle)
-- [3,2,1] [1,2,4] -> [(3,6), (2,3), (1,1)] [(1,7), (2,6), (4,4)]
-- To grab the sum for the whole dequeue we just add 6 and 7 resulting in 13.
-- This property that the front and back partial sums sum to the final result
-- is invariant with pushes and pops. To convince yourself, try a pop:
-- [3,2,1] [2,4] -> [(3,6), (2,3), (1,1)] [(2,6), (4,4)]
-- Adding the partial sums gives 12.
--
-- The last key to the implementation is that pushes only affect the front
-- queue, and pops only affect the back queue. Except, if the back queue is
-- empty, we pop all the elements of the front queue and push them onto the
-- back queue, recalculating all the partial sums in between.
-- [(3,6), (2,3), (1,1)] []
-- -> [] [(1,6), (2,5), (3,3)]
-- This keeps the invariant that both stacks have their partial sums
-- calculated correctly!
--
-- This scheme happens to work for any commutative accumulation function!
-- So I have extended it to accept a user-provided function.
-- IMPORTANT: The accumulation function MUST be commutative or the whole
-- thing fails, since the algorithm rests on being able to combine the two
-- partial sums 'somewhere in the middle'. I am not aware of this algorithm
-- extending to arbitrary associative functions.

data Deque a = Deque
  { acc   :: (a -> a -> a)
  , sz    :: Int
  , front :: [(a, a)]
  , back  :: [(a, a)]
  }

push :: a -> Deque a -> Deque a
push a (Deque f sz [] back)            = Deque f (succ sz) [(a, a)] back
push a (Deque f sz ((x, y) : xs) back) = Deque f (succ sz) front    back
  where
    front = (a, f a y) : (x, y) : xs

deque :: (a -> a -> a) -> Deque a
deque f = Deque f 0 [] []

-- deque implementation for a monoid
mdeque :: Monoid m => Deque m
mdeque = deque mappend

size :: Deque a -> Int
size = sz

pop :: Deque a -> Maybe (a, Deque a)
pop (Deque f sz [] [])     = Nothing
pop (Deque f sz xs (y:ys)) = Just (fst y, Deque f (pred sz) xs ys)
-- When the back is empty, fill it with elements from the front.
-- This does two things, it reverses the elements (so the dequeue is FIFO)
-- and it recalculates the fold over the back end of the deque.
-- While this is an O(n) operation it is amortized O(1) since it only
-- happens once per element.
pop (Deque f sz xs [])     = pop (Deque f sz [] (foldl' go [] xs))
  where
    go [] (a, _)          = [(a, a)]
    go ((y, b):ys) (a, _) = (a, f a b) : (y, b) : ys

popWhile :: (a -> Bool) -> Deque a -> Deque a
popWhile pred d@(Deque f sz _ _) = case pop d of
  Nothing      -> d
  Just (a, d') -> if pred a
    then popWhile pred d'
    else d

-- Simulate running a foldl1 over the deque. Note that while it is
-- semantically the same as running a foldl1, performance-wise it is O(1)
-- since the partial updates have been being calculated all along.
runFold :: Deque a -> Maybe a
runFold (Deque _ _ [] [])                 = Nothing
runFold (Deque _ _ ((x,b):xs) [])         = Just b
runFold (Deque _ _ [] ((y,c):ys))         = Just c
runFold (Deque f _ ((x,b):xs) ((y,c):ys)) = Just (f b c)

