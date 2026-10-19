package main

import "fmt"

func sieve(flags []bool, size int) int {
	primeCount := 0
	for i := 2; i <= size; i++ {
		if flags[i-1] {
			primeCount++
			for k := i + i; k <= size; k += i {
				flags[k-1] = false
			}
		}
	}
	return primeCount
}

func run() int {
	flags := make([]bool, 5000)
	for i := range flags {
		flags[i] = true
	}
	return sieve(flags, 5000)
}

func main() {
	r := 0
	for n := 0; n < 1000; n++ {
		r = run()
	}
	fmt.Println(r)
}
