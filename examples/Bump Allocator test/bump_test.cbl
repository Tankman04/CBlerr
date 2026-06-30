struct Node:
    val: int
    next: *Node

def main() -> int:
    printf("Bump Allocator Test\n".data)
    
    let count = 5
    let arr = bump(count * sizeof(int)) as *int
    
    for i in 0..count:
        arr[i] = (i + 1) * 10
        
    printf("Array allocated via bump:\n".data)
    for i in 0..count:
        printf("  arr[%d] = %d\n".data, i, arr[i])
        
    printf("\nLinked List allocated via bump:\n".data)
    
    let head = bump(sizeof(Node)) as *Node
    head.val = 1
    head.next = 0 as *Node 
    
    let curr = head
    for i in 2..6:
        let new_node = bump(sizeof(Node)) as *Node
        new_node.val = i
        new_node.next = 0 as *Node
        
        curr.next = new_node
        curr = new_node
        
    let it = head
    while it != 0 as *Node:
        printf("  Node val: %d\n".data, it.val)
        it = it.next
        
    printf("\nTest completed successfully.\n".data)
    endofcode