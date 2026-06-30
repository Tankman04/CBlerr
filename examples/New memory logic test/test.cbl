def calculate_primes(limit: int) -> int:
    let byte_size = limit * sizeof(int)
    let is_prime = malloc(byte_size) as *int
    
    for i in 0..limit:
        is_prime[i] = 1
        
    is_prime[0] = 0
    is_prime[1] = 0
    
    for p in 2..limit:
        if is_prime[p] == 1:
            
            let j = p * 2  
            while j < limit:
                is_prime[j] = 0
                j = j + p
                
    let count = 0
    for i in 0..limit:
        if is_prime[i] == 1:
            count = count + 1
            
    free(is_prime as *void)
    
    return count

def main() -> int:
    print(" CBlerr Benchmark: Sieve of Eratosthenes")
    
    let limit = 10000000
    
    printf("Calculating primes up to %d...\n".data, limit)
    
    let start_time = clock()
    let prime_count = calculate_primes(limit)
    let end_time = clock()
    
    let elapsed = end_time - start_time
    
    printf("Result: Found %d primes.\n".data, prime_count)
    printf("Time  : %d ms\n".data, elapsed)
    
    endofcode