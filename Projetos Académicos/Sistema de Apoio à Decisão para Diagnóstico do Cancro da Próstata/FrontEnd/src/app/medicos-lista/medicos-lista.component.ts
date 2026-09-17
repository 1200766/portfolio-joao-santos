import { Component, OnInit } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { Router, RouterModule } from '@angular/router';


import { MedicosService, Medico } from '../services/medicos.service';
import { FilterMedicosPipe } from '../pipes/filter-medicos.pipe';
import { AdministradoresService, User } from '../services/administradores.service';
import { AuthService } from '../services/auth.service';

@Component({
  selector: 'app-utentes-lista',
  standalone: true,
  imports: [
    CommonModule,
    FormsModule,
    FilterMedicosPipe,
    RouterModule
  ],
  templateUrl: './medicos-lista.component.html',
  styleUrls: ['./medicos-lista.component.css']
})
export class MedicosListaComponent implements OnInit {
  medicos: Medico[] = [];
  showInsertModal: boolean = false;
  showModal: boolean = false;
  showViewModal = false;
  medicoVisualizar: any = {};
  novoMedico: Medico = this.criarMedicoVazio();
  medicoSelecionado: Medico = this.criarMedicoVazio();
  showMenu: boolean = false;

  filtroNome: string = '';
  filtroSpeciality: string = '';

  submitted: boolean = false;
  usernameExistente: boolean = false;

  user: User | null = null;

  constructor(
    private medicosService: MedicosService,
    private authService: AuthService,
    private administradoresService: AdministradoresService

  ) { }

  ngOnInit(): void {
    this.medicosService.getMedicos().subscribe(data => {
      this.medicos = data;
    });
    this.user = this.authService.getUser();


  }
  abrirInsertModal(): void {
    this.novoMedico = this.criarMedicoVazio();
    this.showInsertModal = true;
  }
  abrirEditModal(medico: Medico): void {
    this.medicoSelecionado = { ...medico };
    this.showModal = true;
  }
  abrirViewModal(medico: any) {
    this.medicoVisualizar = { ...medico };
    this.showViewModal = true;
  }

  fecharViewModal() {
    this.showViewModal = false;
  }

  fecharInsertModal(): void {
    this.showInsertModal = false;
  }
  fecharEditModal(): void {
    this.showModal = false;
  }
      toggleMenu() {
    console.log('toggleMenu clicado');
    this.showMenu = !this.showMenu;
  }
    logout() {
    this.authService.logout();
  }
  private criarMedicoVazio(): Medico {
    return {
      id: '',
      nome: '',
      contacto: '',
      genero: '',
      nascimento: '',
      proximaConsulta: '',
      password: '',
      email: '',
      username: '',
      specialty: ''
    };
  }

  guardarNovoMedico(): void {
    this.submitted = true;

    const camposPreenchidos =
      this.novoMedico.nome.trim() !== '' &&
      this.novoMedico.contacto.trim() !== '' &&
      this.novoMedico.genero.trim() !== '' &&
      this.novoMedico.nascimento.trim() !== '' &&
      this.novoMedico.email.trim() !== '' &&
      this.novoMedico.username.trim() !== '' &&
      this.novoMedico.password.trim() !== ''; const emailValido = this.isEmailValido();
    const passwordValida = this.isPasswordValida();
    const contactoValido = this.isContactoValido();
    const nascimentoValido = this.isDataNascimentoValida();

    console.log('camposPreenchidos:', camposPreenchidos);
    console.log('emailValido:', emailValido);
    console.log('passwordValida:', passwordValida);
    console.log('contactoValido:', contactoValido);
    console.log('nascimentoValido:', nascimentoValido);

    if (!camposPreenchidos || !emailValido || !passwordValida || !contactoValido || !nascimentoValido || !this.novoMedico.specialty) {
      console.warn('Validação falhou. Não vai continuar.');
      return;
    }

    this.administradoresService.getUsers().subscribe(existing => {
      this.usernameExistente = existing.some(m => m.username === this.novoMedico.username);
      console.log('Username já existe?', this.usernameExistente);

      if (this.usernameExistente) {
        console.warn('Username já existe. Parar.');
        return;
      }

      const payload = {
        nome: this.novoMedico.nome,
        contacto: this.novoMedico.contacto,
        genero: this.novoMedico.genero,
        dataNascimento: new Date(this.novoMedico.nascimento).toISOString(),
        username: this.novoMedico.username,
        email: this.novoMedico.email,
        password: this.novoMedico.password,
        specialty: this.novoMedico.specialty
      };

      this.medicosService.registarMedico(payload).subscribe({
        next: () => {
          this.fecharInsertModal();
          this.medicosService.getMedicos().subscribe(data => {
            this.medicos = data;
          });
          alert('Novo medico inserido com sucesso!');
        },
        error: () => {
          console.error('Erro ao inserir medico:');
          alert('Erro ao inserir novo medico.');
        }
      });
    });
  }
  guardarEdicao(): void {
    this.submitted = true;

    const camposPreenchidos =
      this.medicoSelecionado.nome.trim() !== '' &&
      this.medicoSelecionado.contacto.trim() !== '' &&
      this.medicoSelecionado.genero.trim() !== '' &&
      this.medicoSelecionado.nascimento.trim() !== '';

    const contactoValido = /^\d{9}$/.test(this.medicoSelecionado.contacto);
    const nascimentoValido = new Date(this.medicoSelecionado.nascimento) < new Date();

    console.log('camposPreenchidos:', camposPreenchidos);
    console.log('contactoValido:', contactoValido);
    console.log('nascimentoValido:', nascimentoValido);

    if (!camposPreenchidos || !contactoValido || !nascimentoValido) {
      console.warn('Validação falhou. Não vai continuar.');
      return;
    }
    this.medicosService.atualizarMedico(this.medicoSelecionado).subscribe({
      next: () => {
        const index = this.medicos.findIndex(u => u.id === this.medicoSelecionado.id);
        if (index !== -1) {
          this.medicos[index] = { ...this.medicoSelecionado };
        }
        this.fecharEditModal();
        this.medicosService.getMedicos().subscribe(data => {
          this.medicos = data;
        });
        alert('Médico atualizado com sucesso!');
      },
      error: (err) => {
        console.error('Erro ao atualizar médico:');
        alert('Ocorreu um erro ao atualizar o médico.');
      }
    });

  }

  delete(medico: Medico): void {
    if (confirm(`Tem certeza que deseja eliminar o medico ${medico.nome}?`)) {
      this.medicosService.deleteMedico(medico.username).subscribe({
        next: () => {
          this.medicos = this.medicos.filter(m => m.username !== medico.username);
          this.fecharEditModal();
          alert('Medico eliminado com sucesso!');
        },
        error: (err) => {
          console.error('Erro ao eliminar medico:');
          alert('Erro ao eliminar medico.');
        }
      });
    }

  }


  isContactoValido(): boolean {
    return /^\d{9}$/.test(this.novoMedico.contacto);
  }

  isDataNascimentoValida(): boolean {
    const hoje = new Date();
    const nascimento = new Date(this.novoMedico.nascimento);
    return nascimento < hoje;
  }
  verificarUsername(): void {
    if (!this.novoMedico.username) {
      this.usernameExistente = false;
      return;
    }

    this.administradoresService.getUsers().subscribe(users => {
      this.usernameExistente = users.some(u => u.username === this.novoMedico.username);
    });
  }
  isEmailValido(): boolean {
    const regex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
    return regex.test(this.novoMedico.email);
  }

  isPasswordValida(): boolean {
    return typeof this.novoMedico.password === 'string' && this.novoMedico.password.length >= 6;
  }

  isContactoValidoEdicao(): boolean {
    return /^\d{9}$/.test(this.medicoSelecionado.contacto);
  }

  isDataNascimentoValidaEdicao(): boolean {
    const hoje = new Date();
    const nascimento = new Date(this.medicoSelecionado.nascimento);
    return nascimento < hoje;
  }


}

