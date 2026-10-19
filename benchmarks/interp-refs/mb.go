package main

import "fmt"

func mandelbrot(size int) int {
	sum, byteAcc, bitNum := 0, 0, 0
	for y := 0; y < size; y++ {
		ci := 2.0*float64(y)/float64(size) - 1.0
		for x := 0; x < size; x++ {
			zrzr, zi, zizi := 0.0, 0.0, 0.0
			cr := 2.0*float64(x)/float64(size) - 1.5
			z := 0
			notDone := true
			escape := 0
			for notDone && z < 50 {
				zr := zrzr - zizi + cr
				zi = 2.0*zr*zi + ci
				zrzr = zr * zr
				zizi = zi * zi
				if zrzr+zizi > 4.0 {
					notDone = false
					escape = 1
				}
				z++
			}
			byteAcc = (byteAcc << 1) + escape
			bitNum++
			if bitNum == 8 {
				sum ^= byteAcc
				byteAcc = 0
				bitNum = 0
			} else if x == size-1 {
				byteAcc <<= uint(8 - bitNum)
				sum ^= byteAcc
				byteAcc = 0
				bitNum = 0
			}
		}
	}
	return sum
}

func main() { fmt.Println(mandelbrot(500)) }
