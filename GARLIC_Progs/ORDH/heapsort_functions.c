// Funció per intercanviar dos elements de la llista
void swap(short *a, short *b)
{
    short temp = *a;
    *a = *b;
    *b = temp;
}

// Funció per construir el heap
void heapify(short arr[], short n, short i)
{
    short largest = i;
    short left = 2 * i + 1;
    short right = 2 * i + 2;

    if (left < n && arr[left] > arr[largest])
	{
        largest = left;
    }

    if (right < n && arr[right] > arr[largest])
	{
        largest = right;
    }

    if (largest != i)
	{
        swap(&arr[i], &arr[largest]);
        heapify(arr, n, largest);
    }
}

// Funció principal de heapsort
void heapSort(short arr[], short n)
{
	short i;
    for (i = n / 2 - 1; i >= 0; i--)
	{
        heapify(arr, n, i);
    }

    for (i = n - 1; i > 0; i--)
	{
        swap(&arr[0], &arr[i]);
        heapify(arr, i, 0);
    }
}