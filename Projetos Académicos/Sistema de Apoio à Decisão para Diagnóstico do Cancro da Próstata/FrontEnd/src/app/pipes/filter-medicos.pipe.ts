import { Pipe, PipeTransform } from '@angular/core';

@Pipe({
    name: 'filterMedicos',
    standalone: true  // <-- adiciona isso

})
export class FilterMedicosPipe implements PipeTransform {
    transform(medicos: any[], nome: string, specialty: string): any[] {
        if (!medicos) return [];

        return medicos.filter(u => {
            const nomeMatch = nome ? u.nome.toLowerCase().includes(nome.toLowerCase()) : true;
            const specialtyMatch = 
                !specialty || specialty.toLowerCase() === 'todas' 
                    ? true 
                    : (u.specialty || '').toLowerCase() === specialty.toLowerCase();

            return nomeMatch && specialtyMatch;
        });
    }
}


