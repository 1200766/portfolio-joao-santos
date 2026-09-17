import { Pipe, PipeTransform } from '@angular/core';

@Pipe({
    name: 'filterAdministradores',
    standalone: true  // <-- adiciona isso

})
export class FilterAdministradoresPipe implements PipeTransform {
    transform(medicos: any[], nome: string): any[] {
        if (!medicos) return [];

        return medicos.filter(u => {
            const nomeMatch = nome ? u.nome.toLowerCase().includes(nome.toLowerCase()) : true;

            return nomeMatch ;
        });
    }
}


